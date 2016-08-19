classdef AdaptingSteps < edu.washington.riekelab.protocols.RiekeLabProtocol

    % presents a series of flashes before, during and an adapting step;
    % intended to evaluate the time scale of adaptation
    
    properties
        led                             % Output LED
        
        stepPre = 500                   % Time preceding step (ms)
        stepStim = 1500                 % Step duration (ms)
        stepTail = 1500                 % Time following step (ms)
        
        meanMagnitude = 0               % Magnitude of LED stimulus before and after the step (V)
        stepMagnitude = 0               % Magnitude of LED stimulus during the step (V)
        
        flashDurations = 10             % Duration of flashes (ms)
        
        fixedPreFlashTime = 100         % Time of fixed pre step flash (ms)
        fixedStepFlashTime = 1000       % Time, following step onset, of fixed flash (ms)
        fixedPostFlashTime = 1000       % Time, following step offset, of fixed flash (ms)
        
        fixedPreFlashAmp = 0            % Amplitude of fixed flash during time before step (V)
        fixedStepFlashAmp = 0           % Amplitude of fixed flash during step (V)
        fixedPostFlashAmp = 0           % Amplitude of fixed flash following step (V)

        
        variableStepFlashAmp = 0        % Amplitude of variable step following flash onset (V)
        variablePostFlashAmp = 0        % Amplitude of variable step following flash offset (V)

        variableFlashTimes = [10 20 40 80 160 320] % Times, following step onset or offset, of variable flashes (ms)
        
        amp                             % Input amplifier
    end
    
    properties (Dependent, SetAccess = private)
        amp2                            % Secondary amplifier
    end
    
    properties 
        numberOfAverages = uint16(5)    % Number of families
        interpulseInterval = 0          % Duration between pulses (s)
    end
    
    properties (Dependent, Hidden = true)
       totalTime
       numFlashTimes
    end
    
    properties (Hidden)
        ledType
        ampType
        variableFlashTimesType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            [obj.led, obj.ledType] = obj.createDeviceNamesProperty('LED');
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function p = getPreview(obj, panel)
            p = symphonyui.builtin.previews.StimuliPreview(panel, @()createPreviewStimuli(obj));
            function s = createPreviewStimuli(obj)
                s = cell(1, obj.numFlashTimes);
                for i = 1:obj.numFlashTimes
                    s{i} = obj.createLedStimulus(i);
                end
            end
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            if numel(obj.rig.getDeviceNames('Amp')) < 2
                obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
                obj.showFigure('symphonyui.builtin.figures.MeanResponseFigure', obj.rig.getDevice(obj.amp), ...
                    'groupBy', {'variableFlashTime'});
                obj.showFigure('symphonyui.builtin.figures.ResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, ...
                    'baselineRegion', [0 obj.preTime], ...
                    'measurementRegion', [obj.preTime obj.preTime+obj.stimTime]);
            else
                obj.showFigure('edu.washington.riekelab.figures.DualResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
                obj.showFigure('edu.washington.riekelab.figures.DualMeanResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2), ...
                    'groupBy1', {'variableFlashTime'}, ...
                    'groupBy2', {'variableFlashTime'});
                obj.showFigure('edu.washington.riekelab.figures.DualResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, obj.rig.getDevice(obj.amp2), {@mean, @var}, ...
                    'baselineRegion1', [0 obj.preTime], ...
                    'measurementRegion1', [obj.preTime obj.preTime+obj.stimTime], ...
                    'baselineRegion2', [0 obj.preTime], ...
                    'measurementRegion2', [obj.preTime obj.preTime+obj.stimTime]);
            end
            
            device = obj.rig.getDevice(obj.led);
            device.background = symphonyui.core.Measurement(obj.meanMagnitude, device.background.displayUnits);
        end
        
        function [stim, variableFlashTime] = createLedStimulus(obj, epochNum)
            variableFlashTime = obj.determineVariableFlashTime(epochNum);
            
            % make flashes
            flashPreTimes = [obj.fixedPreFlashTime ...
                obj.stepPre + variableFlashTime ...
                obj.stepPre + obj.fixedStepFlashTime ...
                obj.stepPre + obj.stepStim + variableFlashTime ...
                obj.stepPre + obj.stepStim + obj.fixedPostFlashTime];
            
            flashTailTimes = obj.totalTime - flashPreTimes;
            
            flashAmplitudes = [obj.fixedPreFlashAmp ...
                obj.variableStepFlashAmp ...
                obj.fixedStepFlashAmp ...
                obj.variablePostFlashAmp ...
                obj.fixedPostFlashAmp];
                
            flashStimuli = cell(1, 5);
            for i = 1:5
                gen = symphonyui.builtin.stimuli.PulseGenerator();
                
                gen.preTime = flashPreTimes(i);
                gen.stimTime = obj.flashDurations;
                gen.tailTime = flashTailTimes(i);
                gen.amplitude = flashAmplitudes(i);
                gen.mean = 0;
                gen.sampleRate = obj.sampleRate;
                gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
                
                flashStimuli{i} = gen.generate();
            end
        
            % now make step
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            
            gen.preTime = obj.stepPre;
            gen.stimTime = obj.stepStim;
            gen.tailTime = obj.stepTail;
            gen.amplitude = obj.stepMagnitude - obj.meanMagnitude;
            gen.mean = obj.meanMagnitude;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
            
            stepStimulus = gen.generate();
            
            % sum them into one stimulus
            sumGen = symphony.builtin.stimuli.SumGenerator();
            sumGen.stimuli = {stepStimulus, flashStimuli{:}};
            stim = sumGen.generate();
        end
                
        function time = determineVariableFlashTime(obj, epochNum)
            idx = mod(epochNum - 1, obj.numFlashTimes) + 1;
            time = obj.variableFlashTimes(idx);
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            epochNum = obj.numEpochsPrepared;
            [stim, variableFlashTime] = obj.createLedStimulus(epochNum);

            epoch.addParameter('variableFlashTime', variableFlashTime);
            epoch.addStimulus(obj.rig.getDevice(obj.led), stim);
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            
            if numel(obj.rig.getDeviceNames('Amp')) >= 2
                epoch.addResponse(obj.rig.getDevice(obj.amp2));
            end
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            
            device = obj.rig.getDevice(obj.led);
            interval.addDirectCurrentStimulus(device, device.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages * obj.numFlashTimes;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages * obj.numFlashTimes;
        end
                
        function a = get.amp2(obj)
            amps = obj.rig.getDeviceNames('Amp');
            if numel(amps) < 2
                a = '(None)';
            else
                i = find(~ismember(amps, obj.amp), 1);
                a = amps{i};
            end
        end
        
        function value = get.totalTime(obj)
           value = obj.stepPre + obj.stepStim + obj.stepTail;
        end
        
        function value = get.numFlashTimes(obj)
           value = numel(obj.variableFlashTimes); 
        end
        
    end
    
end

