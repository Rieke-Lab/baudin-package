classdef LedPulseWithRodSaturatingFlashes < edu.washington.riekelab.protocols.RiekeLabProtocol
    % Presents a set of rectangular pulse stimuli to a specified
    % LED and records from a specified amplifier.
    
    % To allow for the isolation of responses generated in cone
    % photoreceptors, this protocol will periodically present a flash
    % between epochs that is intended to saturate the rod photoreceptors.
    
    properties
        led                                 % Output LED
        preTime = 10                        % Pulse leading duration (ms)
        stimTime = 100                      % Pulse duration (ms)
        tailTime = 400                      % Pulse trailing duration (ms)
        lightAmplitude = 0.1                % Pulse amplitude (V or norm. [0-1] depending on LED units)
        lightMean = 0                       % Pulse and LED background mean (V or norm. [0-1] depending on LED units)
        
        rodFlashLed                         % Output LED for rod flash
        rodFlashPreTime                     % Time preceding rod saturating flash (ms)
        rodFlashStimTime                    % Duration of rod saturating flash (ms)
        rodFlashTailTime                    % Time following rod saturating flash (ms)
        rodFlashAmplitude                   % Amplitude of rod flash (V or norm. [0-1] depending on LED units)
        
        epochsBetweenRodFlashes = uint8(5)  % Number of epochs between rod flashes
        
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
    end
    
    properties (Hidden, Dependent = true)
        totalNumberOfEpochs
    end
    
    properties (Constant)
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
                
                % make mean response figures for regular LED pulse and rod
                % adapting flashes
                millisecondsToPoints = @(x) x * obj.sampleRate / 1e3;
                ledPulseResponseFigure = ...
                    obj.showFigure('symphonyui.builtin.figures.CustomFigure', @obj.updateLedPulseResponseFigure);
                ledPulseTotalPoints = millisecondsToPoints(obj.preTime + obj.stimTime + obj.tailTime);
                ledPulseResponseTime = ((1:ledPulseTotalPoints) * 1e3 / obj.sampleRate) - obj.preTime;
                edu.washington.riekelab.baudin.protocols.LedPulseWithRodSaturatingFlashes.FormatCustomFigure( ...
                    ledPulseResponseFigure, 'LED Pulse Mean Response', ledPulseResponseTime)
                
                rodFlashResponseFigure = ...
                    obj.showFigure('symphonyui.builtin.figures.CustomFigure', @obj.updateRodFlashResponseFigure);
                rodFlashTotalPoints = ...
                    millisecondsToPoints(obj.rodFlashPreTime + obj.rodFlashStimTime + obj.rodFlashTailTime);
                rodFlashResponseTime = ((1:rodFlashTotalPoints) * 1e3 / obj.sampleRate) - obj.preTime;
                edu.washington.riekelab.baudin.protocols.LedPulseWithRodSaturatingFlashes.FormatCustomFigure( ...
                    rodFlashResponseFigure, 'Rod Flash Mean Response', rodFlashResponseTime)
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
        
        function updateLedPulseResponseFigure(obj, figureHandler, epoch)
            if ~epoch.parameters( ...
                    edu.washington.riekelab.baudin.protocols.LedPulseWithRodSaturationFlashes.IS_ROD_ADAPTING_FLASH_RESPONSE)
                obj.updateFigureMeanTrace(figureHandler, epoch);
            end
        end
        
        function updateRodFlashResponseFigure(obj, figureHandler, epoch)
            if epoch.parameters( ...
                    edu.washington.riekelab.baudin.protocols.LedPulseWithRodSaturationFlashes.IS_ROD_ADAPTING_FLASH_RESPONSE)
                obj.updateFigureMeanTrace(figureHandler, epoch);
            end
        end
        
        function updateFigureMeanTrace(obj, figureHandler, epoch)
            figureData = figureHandler.getFigureHandle().UserData;
            numberOfPreviousEpochs = figureData.epochCount;
            
            previousFraction = numberOfPreviousEpochs / (numberOfPreviousEpochs + 1);
            newFraction = 1 / (numberOfPreviousEpochs + 1);
            
            figureData.lineHandle.YData = ...
                previousFraction * figureData.lineHandle.YData ...
                + newFraction * epoch.getResponse(obj.rig.getDevice(obj.amp)).getData();
            
            figureData.numberOfPreviousEpochs = figureData.numberOfPreviousEpochs + 1;
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
                    edu.washington.riekelab.baudin.protocols.LedPulseWithRodSaturationFlashes.IS_ROD_ADAPTING_FLASH_RESPONSE, ...
                    true);
            else
                % normal stimulus
                epoch.addStimulus(obj.rig.getDevice(obj.led), obj.createLedStimulus());
                epoch.addParameter( ...
                    edu.washington.riekelab.baudin.protocols.LedPulseWithRodSaturationFlashes.IS_ROD_ADAPTING_FLASH_RESPONSE, ...
                    false);
            end
            
            epoch.addParameter( ...
                edu.washington.riekelab.baudin.protocols.LedPulseWithRodSaturationFlashes.EPOCH_NUMBER, ...
                obj.numEpochsPrepared);
            
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
           value = obj.numberOfAverages + ceil(obj.numberOfAverages / obj.epochsBetweenRodFlashes);
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
    
    methods (Static)
        function FormatCustomFigure(figureHandle, titleString, time)
           axesHandle = axes(figureHandle);
           
           axesHandle.XLabel.String = 'time (ms)';
           axesHandle.Ylabel.String = 'response (mV or pA)';
           axesHandle.Title.String = titleString;
           
           figureHandle.UserData = struct;
           figureHandle.UserData.axesHandle = axesHandle;
           figureHandle.UserData.epochCount = 0;
           figureHandle.UserData.lineHandle = plot(axesHandle, time, zeros(1, numel(time)));
        end
    end    
end

