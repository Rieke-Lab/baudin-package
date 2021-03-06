classdef VariableTimeContrastSteps < edu.washington.riekelab.protocols.RiekeLabProtocol
    
    properties
        led                             % Output LED
        preTime = 500                   % Pulse leading duration (ms)
        stepTimes = [40 500]            % Step durations (ms)
        tailTime = 500                  % Pulse trailing duration (ms)
        contrasts = [100 25]            % Contrast (in percent) of positive and negative steps
        lightMean = 0                   % Pulse and background mean (V)
        tailTimeMinMultiple = 2         % minimum number of stepTimes that tailTime must be
        amp                             % Input amplifier
        numberOfAverages = uint16(5)    % Number of epochs
        interpulseInterval = 0          % Duration between pulses (s)
    end
    
    properties (Hidden)
        ledType
        ampType
        stepTimesType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
        contrastsType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
    end
    
    properties (Dependent)
        totalEpochs
        numStepTimes
        numContrasts
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            [obj.led, obj.ledType] = obj.createDeviceNamesProperty('LED');
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function p = getPreview(obj, panel)
            p = symphonyui.builtin.previews.StimuliPreview(panel, @()obj.createLedStimulus());
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            
            obj.showFigure('symphonyui.builtin.figures.MeanResponseFigure', obj.rig.getDevice(obj.amp), ...
                'groupBy', {'StepTime', 'Contrast'});
            
            obj.showFigure('edu.washington.riekelab.figures.ProgressFigure', obj.totalEpochs);
            
            obj.rig.getDevice(obj.led).background = symphonyui.core.Measurement(obj.lightMean, 'V');
        end
        
        function stim = createLedStimulus(obj, epochNum)
            
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            
            gen.preTime = obj.preTime;
            gen.stimTime = obj.determineStepTime(epochNum);
            gen.tailTime = obj.determineTailTime(gen.stimTime);
            gen.amplitude = obj.percentContrastToVolts( ...
                obj.determineContrast(epochNum));
            gen.mean = obj.lightMean;
            gen.sampleRate = obj.sampleRate;
            gen.units = 'V';
            
            stim = gen.generate();
            
        end
        
        % there is a property: tailTimeMinMultiple, which makes it so that
        % the tail time is at least that many multiples of the step time;
        % if it isn't, it will make the tail time be that many multiples of
        % the step time; if it already is long enough, it will keep the 
        % specified tailTime
        function tailTime = determineTailTime(obj, stepTime)
            tailTime = max(obj.tailTime, stepTime * obj.tailTimeMinMultiple);
        end
                
        function idx = determineStepTimeIdx(obj, epochNum)
            cycleNum = ceil(epochNum / 2);
            idx = mod(cycleNum - 1, obj.numStepTimes) + 1;
        end
        
        function stepTime = determineStepTime(obj, epochNum)
            stepTime = ...
                obj.stepTimes(obj.determineStepTimeIdx(epochNum));
        end
        
        function idx = determineContrastIdx(obj, epochNum)
            idx = mod(ceil(epochNum / 2) - 1, obj.numContrasts) + 1;
        end
        
        function contrast = determineContrast(obj, epochNum)
            magnitude = obj.contrasts(obj.determineContrastIdx(epochNum));
            contrast = 2 * (mod(epochNum, 2) - 0.5) * magnitude;
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            % get epoch number
            epochNum = obj.numEpochsPrepared;
            
            epoch.addStimulus(obj.rig.getDevice(obj.led), obj.createLedStimulus(epochNum));
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            
            
            epoch.addParameter( ...
                'StepTime', obj.determineStepTime(epochNum));
            epoch.addParameter( ...
                'Contrast', obj.determineContrast(epochNum));
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            
            device = obj.rig.getDevice(obj.led);
            interval.addDirectCurrentStimulus(device, device.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.totalEpochs;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.totalEpochs;
        end
        
        function volts = percentContrastToVolts(obj, percentContrast)
            volts = obj.lightMean * percentContrast / 100;
        end
        
    end
    
    % for dependent properites
    methods
        function value = get.totalEpochs(obj)
            % factor of 2 is for +/- contrast
            value = 2 * obj.numStepTimes * obj.numberOfAverages;
        end
        
        function value = get.numStepTimes(obj)
            value = numel(obj.stepTimes);
        end
        
        function value = get.numContrasts(obj)
            value = numel(obj.contrasts);
        end
    end
    
end

