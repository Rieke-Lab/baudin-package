classdef ConeTypingRedGreen < edu.washington.riekelab.protocols.RiekeLabProtocol
    properties
        preTime = 10                    % Pulse leading duration (ms)
        stimTime = 10                   % Pulse duration (ms)
        tailTime = 400                  % Pulse trailing duration (ms)
        redLedAmplitude = 7             % Pulse amplitude (V)
        greenLedAmplitude = 1           % Pulse amplitude (V)
        lightMean = 0                   % Pulse and background mean (V)
        amp                             % Input amplifier
        numberOfAverages = uint16(2)    % Number of epochs
        interpulseInterval = 0          % Duration between pulses (s)
    end
    
    properties (Hidden)
        ledType
        ampType
    end
    
    % plot stuff
    properties (Hidden = true)
        customFigure
        customFigureAxes = [];
        customFigureLines
    end
    
    properties (Constant = true, Hidden = true)
        IDENTIFIER_NAME = 'ledIdentifier';
        RED_IDENTIFIER = 'red';
        GREEN_IDENTIFIER = 'green';
    end
    
    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            obj.customFigure = obj.showFigure('symphonyui.builtin.figures.CustomFigure', @obj.updateFigure);
            obj.initializeCustomFigure();
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('symphonyui.builtin.figures.ResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, ...
                'baselineRegion', [0 obj.preTime], ...
                'measurementRegion', [obj.preTime obj.preTime+obj.stimTime]);
            
            leds = obj.rig.getDevices('LED');
            for i = 1:numel(leds)
                leds{i}.background = symphonyui.core.Measurement(0, 'V');
            end
        end
        
        function initializeCustomFigure(obj)
            if ~isempty(obj.customFigureAxes) && isvalid(obj.customFigureAxes)
                cla(obj.customFigureAxes);
            else
                obj.customFigureAxes = axes('Parent', obj.customFigure.getFigureHandle());
            end
            obj.customFigureLines = containers.Map();
            
            obj.customFigureAxes.NextPlot = 'add';
            obj.customFigureAxes.XLabel.String = 'time (ms)';
            obj.customFigureAxes.YLabel.String = 'response (pA or mV)';
            obj.customFigureAxes.Title.String = 'cone typing';
        end
        
        function updateFigure(obj, ~, epoch)
            response = epoch.getResponse(obj.rig.getDevice(obj.amp)).getData;
            
            ledId = epoch.parameters(obj.IDENTIFIER_NAME);
            if obj.customFigureLines.isKey(ledId)
                currLine = obj.customFigureLines(ledId);
                numPrevious = currLine.UserData;
                numTotal = numPrevious + 1;
                currLine.YData = (response / numTotal) + (numPrevious * currLine.YData / numTotal);
            else
                time = (1:numel(response)) * 1e3 / obj.sampleRate - obj.preTime;
                obj.customFigureLines(ledId) = line(time, response, ...
                    'Parent', obj.customFigureAxes, ...
                    'Color', edu.washington.riekelab.baudin.utils.ConeTypingColors.LOOKUP(ledId), ...
                    'UserData', 1);
            end
        end
        
        function stim = createLedStimulus(obj,ledDevice, ledAmplitude)
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.amplitude = ledAmplitude;
            gen.mean = obj.lightMean;
            gen.sampleRate = obj.sampleRate;
            gen.units = ledDevice.background.displayUnits;
            
            stim = gen.generate();
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            % get epoch number
            if mod(obj.numEpochsPrepared, 2) == 1
                ledDevice = obj.rig.getDevice('Red LED');
                ledIdentifier = obj.RED_IDENTIFIER;
                ledAmplitude = obj.redLedAmplitude;
            else
                ledDevice = obj.rig.getDevice('Green LED');
                ledIdentifier = obj.GREEN_IDENTIFIER;
                ledAmplitude = obj.greenLedAmplitude;
            end
            
            epoch.addStimulus(ledDevice, obj.createLedStimulus(ledDevice, ledAmplitude));
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            epoch.addParameter(obj.IDENTIFIER_NAME, ledIdentifier);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < (obj.numberOfAverages * 2);
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < (obj.numberOfAverages * 2);
        end
    end
end