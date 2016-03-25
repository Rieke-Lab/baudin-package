classdef FrequencyTuning < edu.washington.rieke.protocols.RiekeProtocol
    
    properties
        led                             % Output LED
        preTime = 10                    % Pulse leading duration (ms)
        stimTime = 100                  % Pulse duration (ms)
        tailTime = 400                  % Pulse trailing duration (ms)
        frequencies = [1, 2, 4, 8, 16, 32]
        contrasts = [100, 100, 100, 100, 100, 100]
        lightMean = 0                   % Pulse and background mean (V)
        amp                             % Input amplifier
        numberOfAverages = uint16(5)    % Number of epochs
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
        numFrequencies
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.rieke.protocols.RiekeProtocol(obj);
            
            [obj.led, obj.ledType] = obj.createDeviceNamesProperty('LED');
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function p = getPreview(obj, panel)
            p = symphonyui.builtin.previews.StimuliPreview(panel, @()obj.createLedStimulus());
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.rieke.protocols.RiekeProtocol(obj);
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('symphonyui.builtin.figures.ResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, ...
                'baselineRegion', [0 obj.preTime], ...
                'measurementRegion', [obj.preTime obj.preTime+obj.stimTime]);
            
            obj.rig.getDevice(obj.led).background = symphonyui.core.Measurement(obj.lightMean, 'V');
        end
        
        function stim = createLedStimulus(obj, epochNum)
            
            gen = symphonyui.builtin.stimuli.SineGenerator();
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.amplitude = obj.determineAmplitude(epochNum);
            gen.period = obj.determinePeriod(epochNum);
            gen.mean = obj.lightMean;
            gen.sampleRate = obj.sampleRate;
            gen.units = 'V';
            disp(epochNum)
            disp(gen.period)
            stim = gen.generate();
        end
        
        function amp = determineAmplitude(obj, epochNum)
            amp = obj.determineContrast(epochNum) *obj.lightMean;
        end
        
        function idx = determineFreqIdx(obj, epochNum)
            idx = mod(epochNum - 1, obj.numFrequencies) + 1;
        end
        
        function per = determinePeriod(obj, epochNum)  % in ms
            per = 1000 / obj.determineFrequency(epochNum);
        end
        
        function freq = determineFrequency(obj, epochNum)
            freq = obj.frequencies(obj.determineFreqIdx(epochNum));
        end
        
        function contr = determineContrast(obj, epochNum) %[0, 1]
            contr = obj.contrasts(obj.determineFreqIdx(epochNum)) / 100;
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.rieke.protocols.RiekeProtocol(obj, epoch);
            
            % get epoch number
            epochNum = obj.numEpochsPrepared;
            
            epoch.addStimulus(obj.rig.getDevice(obj.led), obj.createLedStimulus(epochNum));
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            
            %%%%%
            epoch.addParameter(...
                'Frequency', obj.determineFrequency(epochNum));
            epoch.addParameters(...
                'Contrast', obj.determineContrast(epochNum));
            %%%%%
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.rieke.protocols.RiekeProtocol(obj, interval);
            
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
            value = obj.numFrequencies * obj.numberOfAverages;
        end
        
        function value = get.numFrequencies(obj)
            value = numel(obj.frequencies);
        end
    end
    
end

