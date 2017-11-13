classdef LedNoiseConeIsolatingOldSlice < edu.washington.riekelab.protocols.RiekeLabProtocol
    % Presents Gaussian noise stimuli intended to stimulate a signle cone.
    % Stimulus will have a specified mean number of isomerizations as well
    % as a noise standard deviation - also in isomerizations.
    
    properties
        redLedIsomPerVoltS = 0          % S cone isomerizations per volt delivered to red led with given settings
        redLedIsomPerVoltM = 0          % M cone isomerizations per volt delivered to red led with given settings
        redLedIsomPerVoltL = 0          % L cone isomerizations per volt delivered to red led with given settings
        greenLedIsomPerVoltS = 0        % S cone isomerizations per volt delivered to green led with given settings
        greenLedIsomPerVoltM = 0        % M cone isomerizations per volt delivered to green led with given settings
        greenLedIsomPerVoltL = 0        % L cone isomerizations per volt delivered to green led with given settings
        uvLedIsomPerVoltS = 0           % S cone isomerizations per volt delivered to uv led with given settings
        uvLedIsomPerVoltM = 0           % M cone isomerizations per volt delivered to uv led with given settings
        uvLedIsomPerVoltL = 0           % L cone isomerizations per volt delivered to uv led with given settings
        
        preTime = 100                   % Noise leading duration (ms)
        stimTime = 600                  % Noise duration (ms)
        tailTime = 100                  % Noise trailing duration (ms)
        
        frequencyCutoff = 60            % Noise frequency cutoff for smoothing (Hz)
        numberOfFilters = 4             % Number of filters in cascade for noise smoothing
        useRandomSeed = false           % Use a random seed for each standard deviation multiple?
        
        meanIsomerizations = 1000       % Mean number of isomerizations for noise and background in units of isomerizations
        sStdvContrast = 0.5             % S cone noise standard deviation in units of contrast [-1 through 1]
        mStdvContrast = 0.5             % M cone noise standard deviation in units of contrast [-1 through 1]
        lStdvContrast = 0.5             % L cone noise standard deviation in units of contrast [-1 through 1]
        
        amp                             % Input amplifier
    end
    
    properties (Dependent, SetAccess = private)
        amp2                            % Secondary amplifier
    end
    
    properties
        numberOfAverages = uint16(10)   % Number of epochs to deliver
        interpulseInterval = 0          % Duration between noise stimuli (s)
    end
    
    properties (Hidden, Dependent)        
        rguToLms
        lmsToRgu
        
        lmsMeanIsomerizations
        lmsStdvIsomerizations
        
        redLed
        greenLed
        uvLed
    end
    
    properties (Hidden)
        ampType
    end
    
    properties (Constant)
        RED_LED = 'Red LED';
        GREEN_LED = 'Green LED';
        UV_LED = 'UV LED';
        
        S_CONE = 's cone';
        M_CONE = 'm cone';
        L_CONE = 'l cone';
    end
    
    methods
        
        function value = get.rguToLms(obj)
            value = [obj.redLedIsomPerVoltL obj.greenLedIsomPerVoltL obj.uvLedIsomPerVoltL; ...
                obj.redLedIsomPerVoltM obj.greenLedIsomPerVoltM obj.uvLedIsomPerVoltM; ...
                obj.redLedIsomPerVoltS obj.greenLedIsomPerVoltS obj.uvLedIsomPerVoltS];
        end
        
        function value = get.lmsToRgu(obj)
            value = inv(obj.rbuToLms);
        end
        
        function value = get.lmsMeanIsomerizations(obj)
            value = obj.meanIsomerizations * ones(3, 1);
        end
        
        
        function value = get.lmsStdvIsomerizations(obj)
            value = obj.lmsMeanIsomerizations .* [obj.lStdvContrast obj.mStdvContrast obj.sStdvContrast];
        end
        
        function value = get.redLed(obj)
            value = obj.rig.getDevice(edu.washington.riekelab.baudin.protocols.LedNoiseConeIsolating2P.RED_LED);
        end
        
        function value = get.greenLed(obj)
            value = obj.rig.getDevice(edu.washington.riekelab.baudin.protocols.LedNoiseConeIsolating2P.GREEN_LED);
        end
        
        function value = get.uvLed(obj)
            value = obj.rig.getDevice(edu.washington.riekelab.baudin.protocols.LedNoiseConeIsolating2P.UV_LED);
        end
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
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
            
            rguMean = obj.lmsToRgu * obj.lmsMeanIsomerizations;

            obj.redLed.background = symphonyui.core.Measurement(rguMean(1), obj.redLed.background.displayUnits);
            obj.blueLed.background = symphonyui.core.Measurement(rguMean(2), obj.greenLed.background.displayUnits);
            obj.uvLed.background = symphonyui.core.Measurement(rguMean(3), obj.uvLed.background.displayUnits);
        end
        
        function stim = createLedStimulus(obj, seed, voltageMean, voltageStdv, deviceDisplayUnits, inverted)
            gen = edu.washington.riekelab.stimuli.GaussianNoiseGeneratorV2();
            
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.stDev = voltageStdv;
            gen.freqCutoff = obj.frequencyCutoff;
            gen.numFilters = obj.numberOfFilters;
            gen.mean = voltageMean;
            gen.seed = seed;
            gen.inverted = inverted;
            gen.sampleRate = obj.sampleRate;
            gen.units = deviceDisplayUnits;
            
            if strcmp(gen.units, symphonyui.core.Measurement.NORMALIZED)
                gen.upperLimit = 1;
                gen.lowerLimit = 0;
            else
                gen.upperLimit = 10.239;
                gen.lowerLimit = -10.24;
            end
            
            stim = gen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            if ~obj.useRandomSeed
                seed = 0;
            else
                seed = RandStream.shuffleSeed;
            end
            
            rguMean = obj.lmsToRbu * obj.lmsMeanIsomerizations;
            rguStdv = obj.lmsToRbu * obj.lmsStdvIsomerizations;
            
            redStim = obj.createLedStimulus( ...
                seed, rguMean(1), abs(rguStdv(1)), obj.redLed.background.displayUnits, rguStdv(1) < 0);
            blueStim = obj.createLedStimulus( ...
                seed, rguMean(2), abs(rguStdv(2)), obj.blueLed.background.displayUnits, rguStdv(2) < 0);
            uvStim = obj.createLedStimulus( ...
                seed, rguMean(3), abs(rguStdv(3)), obj.uvLed.background.displayUnits, rguStdv(3) < 0);
            
            epoch.addParameter('seed', seed);
            
            epoch.addStimulus(obj.redLed, redStim);
            epoch.addStimulus(obj.blueLed, blueStim);
            epoch.addStimulus(obj.uvLed, uvStim);
            
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            
            if numel(obj.rig.getDeviceNames('Amp')) >= 2
                epoch.addResponse(obj.rig.getDevice(obj.amp2));
            end
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            
            interval.addDirectCurrentStimulus( ...
                obj.redLed, obj.redLed.background, obj.interpulseInterval, obj.sampleRate);
            interval.addDirectCurrentStimulus( ...
                obj.blueLed, obj.greenLed.background, obj.interpulseInterval, obj.sampleRate);
            interval.addDirectCurrentStimulus( ...
                obj.uvLed, obj.uvLed.background, obj.interpulseInterval, obj.sampleRate);
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