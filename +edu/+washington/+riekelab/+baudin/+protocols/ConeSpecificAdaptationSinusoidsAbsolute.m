classdef ConeSpecificAdaptationSinusoidsAbsolute < edu.washington.riekelab.protocols.RiekeLabProtocol
    % Presents a set of rectangular pulse stimuli to a specified LED and records from a specified amplifier.
    
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
        
        constantConeBackground = 1e3;
        changingConeBackgrounds = [1e3 5e3];
        
        coneOnConstantToStimulate = ...
            edu.washington.riekelab.baudin.protocols.ConeSpecificAdaptationSinusoidsAbsolute.L_CONE
            
        coneForChangingBackgrounds = ...
            edu.washington.riekelab.baudin.protocols.ConeSpecificAdaptationSinusoidsAbsolute.M_CONE
        
        preTime = 200                    % Pulse leading duration (ms)
        stimTime = 1000                  % Pulse duration (ms)
        tailTime = 200                  % Pulse trailing duration (ms)
        
        
        sinusoidAbsoluteAmplitude = 100;
        sinusoidFrequency = 4
        
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
        coneOnConstantToStimulateType = symphonyui.core.PropertyType( ...
            'char', 'row', edu.washington.riekelab.baudin.protocols.ConeSpecificAdaptationSinusoidsAbsolute.CONE_TYPES_LMS)
        coneForChangingBackgroundsType = symphonyui.core.PropertyType( ...
            'char', 'row', edu.washington.riekelab.baudin.protocols.ConeSpecificAdaptationSinusoidsAbsolute.CONE_TYPES_LMS)
        ampType
    end
    
    properties (Hidden, Dependent)
        rguToLms
        lmsToRgu
        
        redLed
        greenLed
        uvLed
        
        numberOfBackgroundPairs
    end
    properties (Constant)
        RED_LED = 'Red LED';
        GREEN_LED = 'Green LED';
        UV_LED = 'UV LED';
        
        S_CONE = 's cone';
        M_CONE = 'm cone';
        L_CONE = 'l cone';
        CONE_TYPES_LMS = {edu.washington.riekelab.baudin.protocols.ConeSpecificAdaptationSinusoidsAbsolute.L_CONE, ...
            edu.washington.riekelab.baudin.protocols.ConeSpecificAdaptationSinusoidsAbsolute.M_CONE, ...
            edu.washington.riekelab.baudin.protocols.ConeSpecificAdaptationSinusoidsAbsolute.S_CONE};
    end
    
    methods
        
        function value = get.rguToLms(obj)
            value = [obj.redLedIsomPerVoltL obj.greenLedIsomPerVoltL obj.uvLedIsomPerVoltL; ...
                obj.redLedIsomPerVoltM obj.greenLedIsomPerVoltM obj.uvLedIsomPerVoltM; ...
                obj.redLedIsomPerVoltS obj.greenLedIsomPerVoltS obj.uvLedIsomPerVoltS];
        end
        
        function value = get.lmsToRgu(obj)
            value = inv(obj.rguToLms);
        end
        
        function value = get.redLed(obj)
            value = obj.rig.getDevice(edu.washington.riekelab.baudin.protocols.LedNoiseConeIsolatingOldSlice.RED_LED);
        end
        
        function value = get.greenLed(obj)
            value = obj.rig.getDevice(edu.washington.riekelab.baudin.protocols.LedNoiseConeIsolatingOldSlice.GREEN_LED);
        end
        
        function value = get.uvLed(obj)
            value = obj.rig.getDevice(edu.washington.riekelab.baudin.protocols.LedNoiseConeIsolatingOldSlice.UV_LED);
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
        
        function value = get.numberOfBackgroundPairs(obj)
            value = numel(obj.changingConeBackgrounds);
        end
        
        function [lmsMeans, lmsContrasts, coneWithStimulus] = GetLmsMeanIsomerizations(obj, epochNumber)
            stimulusNumber = mod(epochNumber - 1, 2 * obj.numberOfBackgroundPairs) + 1;
            backgroundNumber = ceil(stimulusNumber / 2);
            contrastNumber = mod(stimulusNumber, 2) == 0;
            
            lmsTypes = edu.washington.riekelab.baudin.protocols.ConeSpecificAdaptationSinusoidsAbsolute.CONE_TYPES_LMS;
            lmsMeans = ...
                obj.constantConeBackground * cellfun(@(x) ~strcmp(x, obj.coneForChangingBackgrounds), lmsTypes)' ...
                + obj.changingConeBackgrounds(backgroundNumber) ...
                * cellfun(@(x) strcmp(x, obj.coneForChangingBackgrounds), lmsTypes)';
            
            isCorrectConeType = @(x) (contrastNumber && strcmp(x, obj.coneOnConstantToStimulate)) ...
                || (~contrastNumber && strcmp(x, obj.coneForChangingBackgrounds));
            lmsContrasts = obj.sinusoidAbsoluteAmplitude * cellfun(isCorrectConeType, lmsTypes)' ./ lmsMeans;
            coneWithStimulus = lmsTypes{cellfun(isCorrectConeType, lmsTypes)};
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            if strcmp(obj.coneOnConstantToStimulate, obj.coneForChangingBackgrounds)
                error('Cone to stimulate and cone for changing backgrounds cannot be the same');
            end
            
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
            
            rguBackgrounds = obj.lmsToRgu * obj.GetLmsMeanIsomerizations(1);
            
            obj.redLed.background = symphonyui.core.Measurement(rguBackgrounds(1), obj.redLed.background.displayUnits);
            obj.greenLed.background = symphonyui.core.Measurement( ...
                rguBackgrounds(2), obj.greenLed.background.displayUnits);
            obj.uvLed.background = symphonyui.core.Measurement(rguBackgrounds(3), obj.uvLed.background.displayUnits);
        end
        
        function stim = createLedStimulus(obj, stimulusMean, stimulusAmplitude, device)
            gen = symphonyui.builtin.stimuli.SineGenerator();
            
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.amplitude = stimulusAmplitude;
            gen.mean = stimulusMean;
            gen.period = 1e3 / obj.sinusoidFrequency;
            gen.sampleRate = obj.sampleRate;
            gen.units = device.background.displayUnits;
            
            stim = gen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            epochNumber = obj.numEpochsPrepared;
            [lmsMeans, lmsContrasts, coneWithStimulus] = obj.GetLmsMeanIsomerizations(epochNumber);
            
            epoch.addParameter('lConeMean', lmsMeans(1));
            epoch.addParameter('lConeContrast', lmsContrasts(1));
            epoch.addParameter('mConeMean', lmsMeans(2));
            epoch.addParameter('mConeContrast', lmsContrasts(2));
            epoch.addParameter('sConeMean', lmsMeans(3));
            epoch.addParameter('sConeContrast', lmsContrasts(3));
            epoch.addParameter('coneWithStimulus', coneWithStimulus);
            
            rguMeans = obj.lmsToRgu * lmsMeans;
            rguContrasts = obj.lmsToRgu * lmsContrasts;
            disp(epochNumber);
            disp(lmsContrasts)
            disp(rguContrasts);
            
            epoch.addStimulus(obj.redLed, obj.createLedStimulus(rguMeans(1), rguContrasts(1), obj.redLed));
            epoch.addStimulus(obj.greenLed, obj.createLedStimulus(rguMeans(2), rguContrasts(2), obj.greenLed));
            epoch.addStimulus(obj.uvLed, obj.createLedStimulus(rguMeans(3), rguContrasts(3), obj.uvLed));
            
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
                obj.greenLed, obj.greenLed.background, obj.interpulseInterval, obj.sampleRate);
            interval.addDirectCurrentStimulus( ...
                obj.uvLed, obj.uvLed.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages * 2 * obj.numberOfBackgroundPairs;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages * 2 * obj.numberOfBackgroundPairs;
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