classdef SingleConeTyping < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    % Presents a set of single spot stimuli to a Stage canvas and records from the specified amplifier.
    
    properties
        amp                             % Output amplifier
        preTime = 200                   % Spot leading duration (ms)
        stimTime = 100                  % Spot duration (ms)
        tailTime = 200                  % Spot trailing duration (ms)
        coneCenters = [50 50; 100 100]
        coneRadii = [20 20]
        backgroundIntensity = 0.5 * ones(1, 3)       % Background light intensity (0-1)
        numberOfAverages = uint16(3)    % Number of epochs
        interpulseInterval = 0          % Duration between spots (s)
    end
    
    properties (Hidden)
        ampType
    end
    
    properties (Dependent, Hidden = true)
        numCones
        numEpochs
    end
    
    properties (Hidden)
       currentColor = []; 
       currentCenter = [];
       currentRadius = [];
       
       tempFileName = ''
    end        
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function p = getPreview(obj, panel)
            if isempty(obj.rig.getDevices('Stage'))
                p = [];
                return;
            end
            p = io.github.stage_vss.previews.StagePreview(panel, @()obj.createPresentation(), ...
                'windowSize', obj.rig.getDevice('Stage').getCanvasSize());
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.figures.MeanResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.figures.FrameTimingFigure', obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
        end
        
        
        
        function p = createPresentation(obj)
            device = obj.rig.getDevice('Stage');         
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(0.5 * ones(1, 3));
            
            spotDiameterPix = device.um2pix(2 * obj.currentRadius);
            
            spot = stage.builtin.stimuli.Ellipse();
            disp(obj.currentColor);
            spot.color = obj.currentColor;
            spot.radiusX = spotDiameterPix / 2;
            spot.radiusY = spotDiameterPix / 2;
            spot.position = obj.currentCenter;
            p.addStimulus(spot);
            
            spotVisible = stage.builtin.controllers.PropertyController(spot, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(spotVisible);
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            
            obj.currentColor = obj.getCurrentSpotColor(obj.numEpochsPrepared);
            disp([num2str(obj.numEpochsPrepared) ', ' num2str(obj.getConeIdx(obj.numEpochsPrepared))]);
            obj.currentRadius = obj.coneRadii(obj.getConeIdx(obj.numEpochsPrepared));
            obj.currentCenter = obj.coneCenters(obj.getConeIdx(obj.numEpochsPrepared), :);
            
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, interval);
            
            device = obj.rig.getDevice(obj.amp);
            interval.addDirectCurrentStimulus(device, device.background, obj.interpulseInterval, obj.sampleRate);
        end

        function value = getCurrentSpotColor(obj, epochNum)
            value = zeros(1, 3);
            value(obj.getColorIdx(epochNum)) = 1;
        end
        
        function value = getConeIdx(obj, epochNum)
            value = floor((epochNum - 1) / double(3 * obj.numberOfAverages)) + 1;
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numEpochs;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numEpochs;
        end
        
        function value = get.numCones(obj)
            value = numel(obj.coneRadii);
        end
        
        function value = get.numEpochs(obj)
            value = obj.numCones * obj.numberOfAverages * 3;
        end 
    end
    
    methods (Static)
        function value = getColorIdx(epochNum)
            value = mod(epochNum - 1, 3) + 1;
        end
    end 
end