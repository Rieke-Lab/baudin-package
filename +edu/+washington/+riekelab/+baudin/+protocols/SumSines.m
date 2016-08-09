classdef SumSines < edu.washington.riekelab.protocols.RiekeLabProtocol
    
    properties
        led                             % Output LED
        
        preTime = 100                    % Pulse leading duration (ms)
        stimTime = 2000                  % Pulse duration (ms)
        tailTime = 100                  % Pulse trailing duration (ms)
        
        baseFrequency = 1
        baseContrast = 50
        basePhase = 0
        
        secondFrequency = 8
        secondContrast = 50
        secondPhase = 0
        
        contrastMultiplier = 2
        
        lightMean = 1                   % Pulse and background mean (V)
        amp                             % Input amplifier
        numberOfAverages = uint16(2)    % Number of epochs
        interpulseInterval = 0          % Duration between pulses (s)
    end
    
    properties (Hidden)
        ledType
        ampType
        frequenciesType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
        contrastsType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
    end
    
    properties (Dependent)
        totalEpochs
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
            obj.showFigure('symphonyui.builtin.figures.ResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, ...
                'baselineRegion', [0 obj.preTime], ...
                'measurementRegion', [obj.preTime obj.preTime+obj.stimTime]);
            
            obj.rig.getDevice(obj.led).background = symphonyui.core.Measurement(obj.lightMean, 'V');
        end
        
        function stim = createLedStimulus(obj, epochNum)
            
            gen = edu.washington.riekelab.baudin.stimuli.SumSinesGenerator();
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            disp(['epochNum in: ' num2str(epochNum)])
            [frequencies, contrasts, phases] = ...
                obj.determineParameters(epochNum);
            
            gen.frequencies = frequencies;
            gen.contrasts = contrasts;
            gen.phases = phases;

            gen.mean = obj.lightMean;
            gen.sampleRate = obj.sampleRate;
            gen.units = 'V';


            stim = gen.generate();
            disp('generated')
        end
        
        function [frequencies, contrasts, phases] = ...
                determineParameters(obj, epochNum)
            stimType = mod(epochNum, 5);
            disp(epochNum)
            disp(stimType)
            if stimType == 1
                frequencies = obj.baseFrequency;
                contrasts = obj.baseContrast;
                phases = obj.basePhase;
            elseif stimType == 2
                frequencies = obj.baseFrequency;
                contrasts = obj.contrastMultiplier * obj.baseContrast;
                phases = obj.basePhase;
            elseif stimType == 3
                frequencies = obj.secondFrequency;
                contrasts = obj.secondContrast;
                phases = obj.secondPhase;
            elseif stimType == 4
                frequencies = obj.secondFrequency;
                contrasts = obj.contrastMultiplier * obj.secondContrast;
                phases = obj.secondPhase;         
            else
                frequencies = [obj.baseFrequency obj.secondFrequency];
                contrasts = [obj.baseContrast obj.secondContrast];
                phases = [obj.basePhase obj.secondPhase];
            end
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            % get epoch number
            epochNum = obj.numEpochsPrepared;
            
            epoch.addStimulus(obj.rig.getDevice(obj.led), obj.createLedStimulus(epochNum));
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            
            [frequencies, contrasts, phases] = ...
                obj.determineParameters(epochNum);
            
            epoch.addParameter(...
                'Frequencies', frequencies);
            epoch.addParameter(...
                'Contrasts', contrasts);
            epoch.addParameter( ...
                'Phases', phases);
            disp('epoch prepared')
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
        
    end
    
    % for dependent properites
    methods
        function value = get.totalEpochs(obj)
            disp('starting total epochs')
            value = 5 * double(obj.numberOfAverages);
            disp('finished total epochs')
        end
    end
    
end

