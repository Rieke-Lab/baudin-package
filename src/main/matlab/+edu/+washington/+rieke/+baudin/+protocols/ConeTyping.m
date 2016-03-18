classdef ConeTyping < symphonyui.core.Protocol
    
    properties
        preTime = 10                    % Pulse leading duration (ms)
        stimTime = 100                  % Pulse duration (ms)
        tailTime = 400                  % Pulse trailing duration (ms)
        redLEDAmplitude = 1             % Pulse amplitude (V)
        greenLEDAmplitude = 1           % Pulse amplitude (V)
        uvLEDAmplitude = 1              % Pulse amplitude (V)
        lightMean = 0                   % Pulse and background mean (V)
        amp                             % Input amplifier
        numberOfAverages = uint16(5)    % Number of epochs
        interpulseInterval = 0          % Duration between pulses (s)
    end
    
    properties (Hidden)
        ledType
        ampType
        plotData
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@symphonyui.core.Protocol(obj);
            
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        
        function prepareRun(obj)
            prepareRun@symphonyui.core.Protocol(obj);
            
            obj.showFigure('symphonyui.builtin.figures.CustomFigure', @obj.updateFigure);
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('symphonyui.builtin.figures.ResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, ...
                'baselineRegion', [0 obj.preTime], ...
                'measurementRegion', [obj.preTime obj.preTime+obj.stimTime]);
        
            leds = obj.rig.getDevices('LED');
            for i = 1:numel(leds)
               leds{i}.background = symphonyui.core.Measurement(0, 'V');
            end
        end
        
        function updateFigure(obj, custFigObj, epoch)
            if obj.numEpochsCompleted == 1
                obj.plotData.figure = custFigObj.getFigureHandle();
                obj.initializeFigure(obj.plotData.figure);                
            end
            % get index of line to add to
            idx = mod(obj.numEpochsCompleted - 1, 3) + 1;
            % increment line's epoch counter
            obj.plotData.lines{idx}.UserData = ...
                obj.plotData.lines{idx}.UserData + 1;
            % update the line
            obj.plotData.lines{idx}.YData = ...
                obj.weightedAverage(obj.plotData.lines{idx}.YData, ...
                epoch.getResponse(obj.rig.getDevice(obj.amp)).getData(), ...
                obj.plotData.lines{idx}.UserData);
        end
        
        function ave = weightedAverage(obj, old, new, overallCount) %#ok<INUSL>
           oldFraction = (overallCount - 1) / overallCount;
           newFraction = 1 / overallCount;
           ave = (oldFraction * old) + (newFraction * new);
        end
        
        function initializeFigure(obj, figHand)
            set(figHand, 'Color', 'w');
            % make figure current
            % figure(figHand);
            % add axes
            obj.plotData.axes = axes(...
                'Parent', figHand, ...
                'NextPlot', 'add');
            
            
            % plot three lines of zero
            totPts = obj.getTotalPts();
            timePts = (1:totPts) / obj.sampleRate;
            obj.plotData.lines = cell(1,3);
            colors = [1 0.2 0.2; 0.2 1 0.2; 0.2 0.2 1];
            for i = 1:3
               obj.plotData.lines{i} = plot(obj.plotData.axes, ...
                   timePts, zeros(1,totPts), ...
                   'Color', colors(i,:), ...
                   'LineWidth', 2); 
               obj.plotData.lines{i}.UserData = 0;
            end
            disp('initialized')
        end
        
        function num = getTotalPts(obj)
            num = (obj.preTime + obj.stimTime + obj.tailTime) * ...
                obj.sampleRate / 1000;
        end
        
        function stim = createLedStimulus(obj,epochNum)
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.amplitude = obj.determineAmplitude(epochNum);
            gen.mean = obj.lightMean;
            gen.sampleRate = obj.sampleRate;
            gen.units = 'V';
            
            stim = gen.generate();
        end
        
        function amp = determineAmplitude(obj, epochNum)
           idx = mod(epochNum - 1, 3) + 1;
           if idx == 1
               amp = obj.redLEDAmplitude;
           elseif idx == 2
               amp  = obj.greenLEDAmplitude;
           else
               amp = obj.uvLEDAmplitude;
           end
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@symphonyui.core.Protocol(obj, epoch);
            
            % get epoch number
            epochNum = obj.numEpochsPrepared;
            
            epoch.addStimulus( ...
                obj.determineDevice(epochNum), ...
                obj.createLedStimulus(epochNum));
            epoch.addResponse(obj.rig.getDevice(obj.amp));
        end
        
        function device = determineDevice(obj, epochNum)
            idx = mod(epochNum - 1, 3) + 1;
            if idx == 1
                device = obj.rig.getDevice('Red LED');
            elseif idx == 2
                device = obj.rig.getDevice('Green LED');
            else
                device = obj.rig.getDevice('UV LED');
            end
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@symphonyui.core.Protocol(obj, interval);
            
%             device = obj.rig.getDevice(obj.led);
%             interval.addDirectCurrentStimulus(device, device.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < (obj.numberOfAverages * 3);
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < (obj.numberOfAverages * 3);
        end

    end
    
end

