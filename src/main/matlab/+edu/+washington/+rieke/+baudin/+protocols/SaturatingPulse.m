classdef SaturatingPulse < edu.washington.riekelab.protocols.RiekeLabProtocol
    
    properties
        led1Mean = 0                    % background for LED 1
        led1Amp = 1                     % step size for LED 1
        led2Mean = 0                    % background for LED 2
        led2Amp = 1                     % step size for LED 2
        led3Mean = 0                    % background for LED 3
        led3Amp = 1                     % step size for LED 3
        preTime = 3000                  % Pulse leading duration (ms)
        stimTime = 3000                 % Pulse duration (ms)
        tailTime = 1000                 % Pulse trailing duration (ms)

        amp                             % Input amplifier
        numberOfAverages = uint16(5)    % Number of epochs
        interpulseInterval = 0          % Duration between pulses (s)
    end
    
    properties (Dependent)
        led1
        led2
        led3
    end
    
    properties (Hidden)
        ledType
        ampType
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function value = get.led1(obj)
            value = obj.getLED(1);
        end
        
        function value = get.led2(obj)
            value = obj.getLED(2);
        end
        
        function value = get.led3(obj)
           value = obj.getLED(3); 
        end
        
        function value = getLED(obj, idx)
            [~, prop] = obj.createDeviceNamesProperty('LED');
            if idx > numel(prop.domain)
                value = 'nothing';
            else 
                value = prop.domain{idx};
            end
        end
        
        function p = getPreview(obj, panel)
            p = symphonyui.builtin.previews.StimuliPreview(panel, @()obj.createLedStimulus(1));
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('symphonyui.builtin.figures.MeanResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('symphonyui.builtin.figures.ResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, ...
                'baselineRegion', [0 obj.preTime], ...
                'measurementRegion', [obj.preTime obj.preTime+obj.stimTime]);
            
            obj.setBackgrounds()
        end
        
        function setBackgrounds(obj)
            for i = 1:3
                if ~strcmp(obj.(['led' num2str(i)]), 'nothing')
                    obj.rig.getDevice(obj.(['led' num2str(i)])).background = ...
                        symphonyui.core.Measurement(obj.(['led' num2str(i) 'Mean']), 'V');   
                end
            end
        end
        
        function stim = createLedStimulus(obj, idx)
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.amplitude = obj.(['led' num2str(idx) 'Amp']);
            gen.mean = obj.(['led' num2str(idx) 'Mean']);
            gen.sampleRate = obj.sampleRate;
            gen.units = 'V';
            
            stim = gen.generate();
        end
        
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
    
            for i = 1:3
                str = ['led' num2str(i)];
                if ~strcmp(obj.(str), 'nothing')
                   epoch.addStimulus( ...
                       obj.rig.getDevice(obj.(str)), ...
                       obj.createLedStimulus(i)); 
                end
            end
            
            epoch.addResponse(obj.rig.getDevice(obj.amp));
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            
            for i = 1:3
                if ~strcmp(obj.(['led' num2str(i)]), 'nothing')
                    dev = obj.rig.getDevice(obj.(['led' num2str(i)]));
                    interval.addDirectCurrentStimulus(dev, dev.background, obj.interpulseInterval, obj.sampleRate);
                end
            end
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
        
    end
    
end

