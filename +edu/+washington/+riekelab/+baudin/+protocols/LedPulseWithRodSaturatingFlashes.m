classdef LedPulseWithRodSaturatingFlashes < edu.washington.riekelab.protocols.RiekeLabProtocol
    % Presents a set of rectangular pulse stimuli to a specified
    % LED and records from a specified amplifier.
    
    % To allow for the isolation of responses generated in cone
    % photoreceptors, this protocol will periodically present a flash
    % between epochs that is intended to saturate the rod photoreceptors.
    
    properties
        led                                 % Output LED
        preTime = 100                       % Pulse leading duration (ms)
        stimTime = 10                       % Pulse duration (ms)
        tailTime = 400                      % Pulse trailing duration (ms)
        lightAmplitude = 0.1                % Pulse amplitude (V or norm. [0-1] depending on LED units)
        lightMean = 0                       % Pulse and LED background mean (V or norm. [0-1] depending on LED units)
        
        rodFlashLed                         % Output LED for rod flash
        rodFlashPreTime = 100               % Time preceding rod saturating flash (ms)
        rodFlashStimTime = 100              % Duration of rod saturating flash (ms)
        rodFlashTailTime = 100              % Time following rod saturating flash (ms)
        rodFlashAmplitude = 1               % Amplitude of rod flash (V or norm. [0-1] depending on LED units)
        
        epochsBetweenRodFlashes = uint16(5)  % Number of epochs between rod flashes
        
        amp                                 % Input amplifier
    end
    
    properties (Dependent, SetAccess = private)
        amp2                                % Secondary amplifier
    end
    
    properties
        numberOfAverages = uint16(25)       % Number of epochs
        interpulseInterval = 0              % Duration between pulses (s)
    end
    
    properties (Hidden)
        ledType
        ampType
        rodFlashLedType
    end
    
    properties (Hidden, Dependent = true)
        totalNumberOfEpochs
    end
    
    properties (Hidden, Constant = true)
        EPOCH_NUMBER = 'epochNumber';
        IS_ROD_ADAPTING_FLASH_RESPONSE = 'isRodAdaptingFlashResponse'
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            [obj.led, obj.ledType] = obj.createDeviceNamesProperty('LED');
            [obj.rodFlashLed, obj.rodFlashLedType] = obj.createDeviceNamesProperty('LED');
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
            
            if numel(obj.rig.getDeviceNames('Amp')) < 2
                obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
                obj.showFigure('symphonyui.builtin.figures.ResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, ...
                    'baselineRegion', [0 obj.preTime], ...
                    'measurementRegion', [obj.preTime obj.preTime+obj.stimTime]);
                
                % make custom figure for mean responses and to led pulses
                % and rod flashes
                customFigure = obj.showFigure('symphonyui.builtin.figures.CustomFigure', @obj.updateFigure);
                obj.formatCustomFigure(customFigure.getFigureHandle());
            else
                obj.showFigure('edu.washington.riekelab.figures.DualResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
                obj.showFigure('edu.washington.riekelab.figures.DualMeanResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
                obj.showFigure('edu.washington.riekelab.figures.DualResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, obj.rig.getDevice(obj.amp2), {@mean, @var}, ...
                    'baselineRegion1', [0 obj.preTime], ...
                    'measurementRegion1', [obj.preTime obj.preTime+obj.stimTime], ...
                    'baselineRegion2', [0 obj.preTime], ...
                    'measurementRegion2', [obj.preTime obj.preTime+obj.stimTime]);
            end
            
            device = obj.rig.getDevice(obj.led);
            device.background = symphonyui.core.Measurement(obj.lightMean, device.background.displayUnits);
        end
        
        function updateFigure(obj, figureHandler, epoch)
            if epoch.parameters( ...
                    edu.washington.riekelab.baudin.protocols.LedPulseWithRodSaturatingFlashes.IS_ROD_ADAPTING_FLASH_RESPONSE)
                obj.updateLine(figureHandler.getFigureHandle().UserData.rodFlashLineHandle, epoch);
            else
                obj.updateLine(figureHandler.getFigureHandle().UserData.ledPulseLineHandle, epoch);
            end
        end
        
        function updateLine(obj, lineHandle, epoch)
            previousFraction = lineHandle.UserData / (lineHandle.UserData + 1);
            newFraction = 1 / (lineHandle.UserData + 1);
            
            lineHandle.YData = ...
                previousFraction * lineHandle.YData ...
                + newFraction * epoch.getResponse(obj.rig.getDevice(obj.amp)).getData();
            
            lineHandle.UserData = lineHandle.UserData + 1;
        end
        
        function stim = createLedStimulus(obj)
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.amplitude = obj.lightAmplitude;
            gen.mean = obj.lightMean;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
            
            stim = gen.generate();
        end
        
        function stim = createRodFlashStimulus(obj)
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            
            gen.preTime = obj.rodFlashPreTime;
            gen.stimTime = obj.rodFlashStimTime;
            gen.tailTime = obj.rodFlashTailTime;
            gen.amplitude = obj.rodFlashAmplitude;
            gen.mean = 0;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
            
            stim = gen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            if mod(obj.numEpochsPrepared, obj.epochsBetweenRodFlashes + 1) == 1
                % rod saturating flash
                epoch.addStimulus(obj.rig.getDevice(obj.rodFlashLed), obj.createRodFlashStimulus());
                epoch.addParameter( ...
                    edu.washington.riekelab.baudin.protocols.LedPulseWithRodSaturatingFlashes.IS_ROD_ADAPTING_FLASH_RESPONSE, ...
                    true);
            else
                % normal stimulus
                epoch.addStimulus(obj.rig.getDevice(obj.led), obj.createLedStimulus());
                epoch.addParameter( ...
                    edu.washington.riekelab.baudin.protocols.LedPulseWithRodSaturatingFlashes.IS_ROD_ADAPTING_FLASH_RESPONSE, ...
                    false);
            end
            
            epoch.addParameter( ...
                edu.washington.riekelab.baudin.protocols.LedPulseWithRodSaturatingFlashes.EPOCH_NUMBER, ...
                obj.numEpochsPrepared);
            
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
        
        function value = get.totalNumberOfEpochs(obj)
            value = ...
                double(obj.numberOfAverages) ...
                + ceil(double(obj.numberOfAverages) / double(obj.epochsBetweenRodFlashes));
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
        
        function formatCustomFigure(obj, figureHandle)
            % hacky way to size figure, hopefully only on first run through
            if isempty(figureHandle.Children)
                figureHandle.Position(3) = 900;
                figureHandle.Position(4) = 350;
            end
            
            clf(figureHandle)
            figureHandle.UserData = struct;
            ledPulseAxesHandle = subplot(1, 2, 1, 'Parent', figureHandle);
            rodFlashAxesHandle = subplot(1, 2, 2, 'Parent', figureHandle);
            
            millisecondsToPoints = @(x) x * obj.sampleRate / 1e3;
            ledPulseTotalPoints = millisecondsToPoints(obj.preTime + obj.stimTime + obj.tailTime);
            ledPulseTime = ((1:ledPulseTotalPoints) * 1e3 / obj.sampleRate) - obj.preTime;
            rodFlashTotalPoints = ...
                millisecondsToPoints(obj.rodFlashPreTime + obj.rodFlashStimTime + obj.rodFlashTailTime);
            rodFlashTime = ((1:rodFlashTotalPoints) * 1e3 / obj.sampleRate) - obj.preTime;
            
            figureHandle.UserData.ledPulseLineHandle = plot(ledPulseTime, zeros(1, numel(ledPulseTime)), ...
                'UserData', 0, ...
                'Parent', ledPulseAxesHandle);
            figureHandle.UserData.rodFlashLineHandle = plot(rodFlashTime, zeros(1, numel(rodFlashTime)), ...
                'UserData', 0, ...
                'Parent', rodFlashAxesHandle);

            ledPulseAxesHandle.XLabel.String = 'time (ms)';
            ledPulseAxesHandle.YLabel.String = 'response (mV or pA)';
            ledPulseAxesHandle.Title.String = 'LED Pulse Response';
            ledPulseAxesHandle.XLim = [-obj.preTime (obj.stimTime + obj.tailTime)];
            figureHandle.UserData.ledPulseAxesHandle = ledPulseAxesHandle;

            rodFlashAxesHandle.XLabel.String = 'time (ms)';
            rodFlashAxesHandle.Title.String = 'Rod Sat. Flash Response';
            rodFlashAxesHandle.XLim = [-obj.rodFlashPreTime (obj.rodFlashStimTime + obj.rodFlashTailTime)];
            figureHandle.UserData.rodFlashAxesHandle = rodFlashAxesHandle;
        end
    end
end

