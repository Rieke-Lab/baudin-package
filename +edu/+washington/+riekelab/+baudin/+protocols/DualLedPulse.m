classdef DualLedPulse < edu.washington.riekelab.protocols.RiekeLabProtocol
    % Presents a set of rectangular pulse stimuli to a specified LED and records from a specified amplifier.
    
    properties
        firstLed                             % Output LED
        secondLed
        preTime = 10                    % Pulse leading duration (ms)
        stimTime = 100                  % Pulse duration (ms)
        tailTime = 400                  % Pulse trailing duration (ms)
        firstLedAmplitude = 0.1
        firstLedMean = 0
        secondLedAmplitude = 0.1
        secondLedMean = 0
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
        firstLedType
        secondLedType
        ampType
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            [obj.firstLed, obj.firstLedType] = obj.createDeviceNamesProperty('LED');
            [obj.secondLed, obj.secondLedType] = obj.createDeviceNamesProperty('LED');
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, name);
            
            if strncmp(name, 'amp2', 4) && numel(obj.rig.getDeviceNames('Amp')) < 2
                d.isHidden = true;
            end
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            if numel(obj.rig.getDeviceNames('Amp')) < 2
                obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
                obj.showFigure('symphonyui.builtin.figures.MeanResponseFigure', obj.rig.getDevice(obj.amp));
                obj.showFigure('symphonyui.builtin.figures.ResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, ...
                    'baselineRegion', [0 obj.preTime], ...
                    'measurementRegion', [obj.preTime obj.preTime+obj.stimTime]);
            else
                obj.showFigure('edu.washington.riekelab.figures.DualResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
                obj.showFigure('edu.washington.riekelab.figures.DualMeanResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
                obj.showFigure('edu.washington.riekelab.figures.DualResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, obj.rig.getDevice(obj.amp2), {@mean, @var}, ...
                    'baselineRegion1', [0 obj.preTime], ...
                    'measurementRegion1', [obj.preTime obj.preTime+obj.stimTime], ...
                    'baselineRegion2', [0 obj.preTime], ...
                    'measurementRegion2', [obj.preTime obj.preTime+obj.stimTime]);
            end
            
            firstDevice = obj.rig.getDevice(obj.firstLed);
            firstDevice.background = symphonyui.core.Measurement(obj.firstLedMean, firstDevice.background.displayUnits);
            
            secondDevice = obj.rig.getDevice(obj.secondLed);
            secondDevice.background = symphonyui.core.Measurement(obj.secondLedMean, secondDevice.background.displayUnits);
        end
        
        function stim = createLedStimulus(obj, lightMean, lightAmplitude, deviceUnits)
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.amplitude = lightAmplitude;
            gen.mean = lightMean;
            gen.sampleRate = obj.sampleRate;
            gen.units = deviceUnits;
            
            stim = gen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            if strcmp(obj.firstLed, obj.secondLed)
                error('LEDs must be different');
            end
            
            firstLedDevice = obj.rig.getDevice(obj.firstLed);
            epoch.addStimulus( ...
                firstLedDevice, ...
                obj.createLedStimulus(obj.firstLedMean, obj.firstLedAmplitude, firstLedDevice.background.displayUnits));
            
            secondLedDevice = obj.rig.getDevice(obj.secondLed);
            epoch.addStimulus( ...
                secondLedDevice, ...
                obj.createLedStimulus(obj.secondLedMean, obj.secondLedAmplitude, secondLedDevice.background.displayUnits));
            
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            
            if numel(obj.rig.getDeviceNames('Amp')) >= 2
                epoch.addResponse(obj.rig.getDevice(obj.amp2));
            end
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            keyboard
            firstDevice = obj.rig.getDevice(obj.firstLed);
            interval.addDirectCurrentStimulus(firstDevice, firstDevice.background, obj.interpulseInterval, obj.sampleRate);
            secondDevice = obj.rig.getDevice(obj.secondLed);
            interval.addDirectCurrentStimulus(secondDevice, secondDevice.background, obj.interpulseInterval, obj.sampleRate);
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

