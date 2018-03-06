classdef ConeSpecificAdaptationNoiseAbsolute < edu.washington.riekelab.protocols.RiekeLabProtocol
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
        changingConeBackgrounds = [1e3 3e3];
        
        coneOnConstantToStimulate = ...
            edu.washington.riekelab.baudin.protocols.ConeSpecificAdaptationSinusoidsAbsolute.M_CONE
        
        coneForChangingBackgrounds = ...
            edu.washington.riekelab.baudin.protocols.ConeSpecificAdaptationSinusoidsAbsolute.L_CONE
        
        epochsPerConePerBackgroundPerCycle = 3;
        numberOfCycles = 10;
        
        preTime = 400                    % Pulse leading duration (ms)
        stimTime = 3000                  % Pulse duration (ms)
        tailTime = 300                  % Pulse trailing duration (ms)
        
        backgroundChangeAdaptationTime = 5000;
        betweenEpochTime = 0;
        
        constantBackgroundNoiseStdv = 100;
        firstChangingBackgroundNoiseStdv = 100;
        secondChangingBackgroundNoiseStdv = 300;
        
        frequencyCutoff = 60;
        numberOfFilters = 4;
        useRandomSeed = true;
        
        amp                             % Input amplifier
    end
    
    properties (Dependent, SetAccess = private)
        amp2                            % Secondary amplifier
    end
    
    properties (Hidden)
        coneOnConstantToStimulateType = symphonyui.core.PropertyType( ...
            'char', 'row', edu.washington.riekelab.baudin.protocols.ConeSpecificAdaptationSinusoidsAbsolute.CONE_TYPES_LMS)
        coneForChangingBackgroundsType = symphonyui.core.PropertyType( ...
            'char', 'row', edu.washington.riekelab.baudin.protocols.ConeSpecificAdaptationSinusoidsAbsolute.CONE_TYPES_LMS)
        ampType
    end
    
    properties (Hidden, Access = private)
        coneToStimulateByEpoch = [];
    end
    
    properties (Hidden, Dependent)
        rguToLms
        lmsToRgu
        
        redLed
        greenLed
        uvLed
        
        epochsPerBackgroundPerCycle
        epochsPerCycle
        totalNumberOfEpochs
    end
    properties (Constant)
        RED_LED = 'Red LED';
        GREEN_LED = 'Green LED';
        UV_LED = 'UV LED';
        
        S_CONE = 's cone';
        M_CONE = 'm cone';
        L_CONE = 'l cone';
        CONE_TYPES_LMS = {edu.washington.riekelab.baudin.protocols.ConeSpecificAdaptationNoiseAbsolute.L_CONE, ...
            edu.washington.riekelab.baudin.protocols.ConeSpecificAdaptationNoiseAbsolute.M_CONE, ...
            edu.washington.riekelab.baudin.protocols.ConeSpecificAdaptationNoiseAbsolute.S_CONE};
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
        
        function value = get.epochsPerBackgroundPerCycle(obj)
            value = 2 * obj.epochsPerConePerBackgroundPerCycle;
        end
        
        function value = get.epochsPerCycle(obj)
            value = 2 * obj.epochsPerBackgroundPerCycle;
        end
        
        function value = get.totalNumberOfEpochs(obj)
            value = obj.epochsPerCycle * obj.numberOfCycles;
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
        
        function [lmsMeans, lmsStdvs, coneWithStimulus] = GetLmsIsomerizationsFromEpochNumber(obj, epochNumber)
            % figure out background combination
            lmsTypes = edu.washington.riekelab.baudin.protocols.ConeSpecificAdaptationNoiseAbsolute.CONE_TYPES_LMS;
            
            changingBackgroundIndex = 2 - (mod(floor((epochNumber - 1) / obj.epochsPerBackgroundPerCycle), 2) == 0);
            
            lmsMeans = obj.constantConeBackground * cellfun(@(x) ~strcmp(x, obj.coneForChangingBackgrounds), lmsTypes) ...
                + obj.changingConeBackgrounds(changingBackgroundIndex) * cellfun(@(x) strcmp(x, obj.coneForChangingBackgrounds), lmsTypes);
            lmsMeans = reshape(lmsMeans, [3, 1]);
            
            % figure out cone for stimulus and L, M, and S standard
            % deviations
            lmsStdvLookup = containers.Map(lmsTypes, num2cell(zeros(1, 3)));
            if obj.coneToStimulateByEpoch(epochNumber)
                % if true, stimulate cone on constant background
                coneWithStimulus = obj.coneOnConstantToStimulate;
                lmsStdvLookup(coneWithStimulus) = obj.constantBackgroundNoiseStdv;
            else
                % if false, stimulate cone with changing background (also
                % need to figure out what stdv to use here)
                coneWithStimulus = obj.coneForChangingBackgrounds;
                lmsStdvLookup(coneWithStimulus) = ...
                    (changingBackgroundIndex == 1) * obj.firstChangingBackgroundNoiseStdv ...
                    + (changingBackgroundIndex == 2) * obj.secondChangingBackgroundNoiseStdv ;
            end
            
            lmsStdvs = reshape(cellfun(@(x) lmsStdvLookup(x), lmsTypes), [3 1]);
        end
        
        function lmsMeans = GetLmsMeanIsomerizationsFromIntervalNumber(obj, intervalNumber)
            % slightly different logic for relating interval number of lms
            % means than was used for epoch number
            lmsTypes = edu.washington.riekelab.baudin.protocols.ConeSpecificAdaptationNoiseAbsolute.CONE_TYPES_LMS;
            
            changingBackgroundIndex = 2 - (mod(floor((intervalNumber) / obj.epochsPerBackgroundPerCycle), 2) == 0);
            
            lmsMeans = obj.constantConeBackground * cellfun(@(x) ~strcmp(x, obj.coneForChangingBackgrounds), lmsTypes) ...
                + obj.changingConeBackgrounds(changingBackgroundIndex) * cellfun(@(x) strcmp(x, obj.coneForChangingBackgrounds), lmsTypes);
            lmsMeans = reshape(lmsMeans, [3, 1]);
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            % check validity of selected cone types
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
            
            obj.coneToStimulateByEpoch = obj.CreateStimulusOrderForRun();
            
            rguBackgrounds = obj.lmsToRgu * obj.GetLmsIsomerizationsFromEpochNumber(1);
            
            obj.redLed.background = symphonyui.core.Measurement(rguBackgrounds(1), obj.redLed.background.displayUnits);
            obj.greenLed.background = symphonyui.core.Measurement( ...
                rguBackgrounds(2), obj.greenLed.background.displayUnits);
            obj.uvLed.background = symphonyui.core.Measurement(rguBackgrounds(3), obj.uvLed.background.displayUnits);
        end
        
        function stimulusOrder = CreateStimulusOrderForRun(obj)
            % create random boolean vector controlling which cone is
            % stimluated for each epoch (each cone will be stimulated the
            % same number of times on each background each cycle, but
            % within the given background/cycle, the order will be random
            singleCycleOrderedBooleans = ...
                [true(1, obj.epochsPerConePerBackgroundPerCycle) false(1, obj.epochsPerConePerBackgroundPerCycle)];
            stimulusOrder = cell2mat(arrayfun( ...
                @(x) singleCycleOrderedBooleans(randperm(obj.epochsPerBackgroundPerCycle)), ...
                (1:2 * obj.numberOfCycles), ...
                'UniformOutput', false));
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
                gen.upperLimit = edu.washington.riekelab.baudin.protocols.LedNoiseConeIsolatingOldSlice.LED_MAX;
                gen.lowerLimit = edu.washington.riekelab.baudin.protocols.LedNoiseConeIsolatingOldSlice.LED_MIN;
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
            
            epochNumber = obj.numEpochsPrepared;
            [lmsMeans, lmsStdvs, coneWithStimulus] = obj.GetLmsIsomerizationsFromEpochNumber(epochNumber);
            
            epoch.addParameter('lConeMean', lmsMeans(1));
            epoch.addParameter('lConeStdv', lmsStdvs(1));
            epoch.addParameter('mConeMean', lmsMeans(2));
            epoch.addParameter('mConeStdv', lmsStdvs(2));
            epoch.addParameter('sConeMean', lmsMeans(3));
            epoch.addParameter('sConeStdv', lmsStdvs(3));
            epoch.addParameter('coneWithStimulus', coneWithStimulus);
            
            rguMeans = obj.lmsToRgu * lmsMeans;
            rguStdvs = obj.lmsToRgu * lmsStdvs;
            
            redStimulus = obj.createLedStimulus( ...
                seed, rguMeans(1), abs(rguStdvs(1)), obj.redLed.background.displayUnits, rguStdvs(1) < 0);
            greenStimulus = obj.createLedStimulus( ...
                seed, rguMeans(2), abs(rguStdvs(2)), obj.greenLed.background.displayUnits, rguStdvs(2) < 0);
            uvStimulus = obj.createLedStimulus( ...
                seed, rguMeans(3), abs(rguStdvs(3)), obj.uvLed.background.displayUnits, rguStdvs(3) < 0);
            
            epoch.addStimulus(obj.redLed, redStimulus);
            epoch.addStimulus(obj.greenLed, greenStimulus);
            epoch.addStimulus(obj.uvLed, uvStimulus);
            
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            if numel(obj.rig.getDeviceNames('Amp')) >= 2
                epoch.addResponse(obj.rig.getDevice(obj.amp2));
            end
            
            percentOutOfRange = @(x) 100 * (sum(x.getData() <= 0) ...
                + sum(x.getData() == edu.washington.riekelab.baudin.protocols.LedNoiseConeIsolatingOldSlice.LED_MAX)) ...
                / (obj.sampleRate * obj.stimTime / 1e3);
            
            fprintf('Epoch: %i\n', epochNumber);
            fprintf('l mean: %.2f, m mean: %.2f, s mean: %.2f\n', lmsMeans(1), lmsMeans(2), lmsMeans(3));
            fprintf('l stdv: %.2f, m stdv: %.2f, s stdv: %.2f\n', lmsStdvs(1), lmsStdvs(2), lmsStdvs(3));
            fprintf('cone with stimulus: %s\n', coneWithStimulus);
            fprintf('red mean: %.2f, green mean: %.2f, uv mean: %.2f\n', rguMeans(1), rguMeans(2), rguMeans(3));
            fprintf('red stdv: %.2f, green stdv: %.2f, uv stdv: %.2f\n', rguStdvs(1), rguStdvs(2), rguStdvs(3));
            fprintf('red out of range: %.2f%%, green: %.2f%%, uv: %.2f%%\n\n', ...
                percentOutOfRange(redStimulus), percentOutOfRange(greenStimulus), percentOutOfRange(uvStimulus));
            
            
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            
            % figure out interpulse interval duration
            intervalNumber = obj.numIntervalsPrepared;
            if mod(intervalNumber, obj.epochsPerBackgroundPerCycle) == 0
                intervalDuration = obj.backgroundChangeAdaptationTime / 1e3;
            else
                intervalDuration = obj.betweenEpochTime / 1e3;
            end
            
            lmsMeans = obj.GetLmsMeanIsomerizationsFromIntervalNumber(intervalNumber);
            rguMeans = obj.lmsToRgu * lmsMeans;
            
            redBackground = symphonyui.core.Measurement(rguMeans(1), obj.redLed.background.displayUnits);
            greenBackground = symphonyui.core.Measurement(rguMeans(2), obj.greenLed.background.displayUnits);
            uvBackground = symphonyui.core.Measurement(rguMeans(3), obj.uvLed.background.displayUnits);
            
            interval.addDirectCurrentStimulus(obj.redLed, redBackground, intervalDuration, obj.sampleRate);
            interval.addDirectCurrentStimulus(obj.greenLed, greenBackground, intervalDuration, obj.sampleRate);
            interval.addDirectCurrentStimulus(obj.uvLed, uvBackground, intervalDuration, obj.sampleRate);
            
            fprintf('Interval: %i\n', intervalNumber);
            fprintf('l mean: %.2f, m mean: %.2f, s mean: %.2f\n', lmsMeans(1), lmsMeans(2), lmsMeans(3));
            fprintf('red mean: %.2f, green mean: %.2f, uv mean: %.2f\n\n', rguMeans(1), rguMeans(2), rguMeans(3));
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.totalNumberOfEpochs;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.totalNumberOfEpochs;
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