classdef NoiseStepWithFlashes < edu.washington.riekelab.protocols.RiekeLabProtocol
    % Presents a set of rectangular pulse stimuli to a specified LED and records from a specified amplifier.
    
    properties
        led                             % Output LED
        preTime = 1000
        noiseStepTime = 3000
        flashStimTime = 10
        flashTailTime = 400
        tailTime = 3000
        numberOfFlashes = 5
        lightMean = 0
        noiseStepAmplitude = 1
        flashAmplitude = 0.1
        amp                             % Input amplifier
    end
    
    properties (Dependent, SetAccess = private)
        amp2                            % Secondary amplifier
    end
    
    properties
        numberOfAverages = uint16(5)    % Number of epochs
        interpulseInterval = 0          % Duration between pulses (s)
    end
    
    properties (Hidden)
        ledType
        ampType
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);      
            [obj.led, obj.ledType] = obj.createDeviceNamesProperty('LED');
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, name);
            
            if strncmp(name, 'amp2', 4) && numel(obj.rig.getDeviceNames('Amp')) < 2
                d.isHidden = true;
            end
        end
        
        function p = getPreview(obj, panel)
            p = symphonyui.builtin.previews.StimuliPreview(panel, @()obj.createLedStimulus());
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            stepBounds = [obj.preTime obj.preTime + obj.noiseStepTime + obj.numberOfFlashes * (obj.flashStimTime + obj.flashTailTime)];
            if numel(obj.rig.getDeviceNames('Amp')) < 2
                obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
                obj.showFigure('symphonyui.builtin.figures.MeanResponseFigure', obj.rig.getDevice(obj.amp));
%                 obj.showFigure('symphonyui.builtin.figures.ResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, ...
%                     'baselineRegion', [0 obj.preTime], ...
%                     'measurementRegion', stepBounds);
            else
                obj.showFigure('edu.washington.riekelab.figures.DualResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
                obj.showFigure('edu.washington.riekelab.figures.DualMeanResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
%                 obj.showFigure('edu.washington.riekelab.figures.DualResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, obj.rig.getDevice(obj.amp2), {@mean, @var}, ...
%                     'baselineRegion1', [0 obj.preTime], ...
%                     'measurementRegion1', stepBounds, ...
%                     'baselineRegion2', [0 obj.preTime], ...
%                     'measurementRegion2', stepBounds);
            end
            
            device = obj.rig.getDevice(obj.led);
            device.background = symphonyui.core.Measurement(obj.lightMean, device.background.displayUnits);
        end
        
        function stim = createLedStimulus(obj)
            flashChunkTime = obj.flashStimTime + obj.flashTailTime;
            
            stepGenerator = symphonyui.builtin.stimuli.PulseGenerator();
            stepGenerator.preTime = obj.preTime;
            stepGenerator.stimTime = obj.noiseStepTime + obj.numberOfFlashes * flashChunkTime;
            stepGenerator.tailTime = obj.tailTime;
            stepGenerator.amplitude = obj.noiseStepAmplitude;
            stepGenerator.mean = obj.lightMean;
            stepGenerator.sampleRate = obj.sampleRate;
            stepGenerator.units = obj.rig.getDevice(obj.led).background.displayUnits;
            stepStimulus = stepGenerator.generate();
            
            flashStimuli = cell(1, obj.numberOfFlashes);
            for i = 1:obj.numberOfFlashes
                gen = symphonyui.builtin.stimuli.PulseGenerator();
                gen.preTime = obj.preTime + obj.noiseStepTime + (i - 1) * flashChunkTime;
                gen.stimTime = obj.flashStimTime;
                gen.tailTime = obj.flashTailTime + (obj.numberOfFlashes - i) * flashChunkTime + obj.tailTime;
                gen.amplitude = obj.flashAmplitude;
                gen.mean = 0;
                gen.sampleRate = obj.sampleRate;
                gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
                flashStimuli{i} = gen.generate();
            end
            
            % sum them into one stimulus
            sumGen = symphonyui.builtin.stimuli.SumGenerator();
            sumGen.stimuli = [{stepStimulus} flashStimuli];
            stim = sumGen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            epoch.addStimulus(obj.rig.getDevice(obj.led), obj.createLedStimulus());
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
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
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
    end
end

