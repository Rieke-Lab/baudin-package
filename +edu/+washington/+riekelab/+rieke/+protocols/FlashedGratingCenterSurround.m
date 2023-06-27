classdef FlashedGratingCenterSurround < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        preTime = 200 % ms
        stimTime = 200 % ms
        tailTime = 200 % ms
        
        spotDiameter = 200 % um
        spotContrast = 0.5;
        centerGrateBarSize = 60; % um
        centerGrateContrast = [0 0.9];
        annulusInnerDiameter = 300; %  um
        surroundMeanContrast = 0.5;
        surroundGrateContrast = [0 0.25 0.5 0.75];
        surroundGrateBarSize = 100;
        backgroundIntensity = 0.5; %0-1
        
        randomize = true;
        onlineAnalysis = 'none'
        amp % Output amplifier
        numberOfAverages = uint16(16) % number of epochs to queue
    end
    
    properties (Hidden)
        
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        surroundIntensityValues
        surroundContrastSequence
        
        %saved out to each epoch...
        stimulusTag
        stimIndex
%         currentSurroundGrateContrast
%         currentSurroundMeanContrast
%         currentCenterGrateContrast
        counter
        sequence
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.turner.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'groupBy',{'stimulusTag'});
            obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            
            obj.sequence = [repmat(obj.centerGrateContrast',length(obj.surroundGrateContrast),1), ...
                            repelem(obj.surroundGrateContrast',length(obj.centerGrateContrast))];
            
            if obj.randomize 
                i = randperm(size(obj.sequence,1));
                obj.sequence = obj.sequence(i,:);
            end
            
            duplicates = ceil(obj.numberOfAverages ./ size(obj.sequence,1));
            obj.sequence = repmat(obj.sequence,duplicates,1);
      
            obj.counter = 1;
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            
%             obj.stimIndex = mod(obj.numEpochsCompleted,2);
%             switch obj.stimIndex
%                 
%                 case 0
%                     obj.stimulusTag = 's_grate_grate';
%                     obj.currentCenterGrateContrast = obj.centerGrateContrast;
%                     obj.currentSurroundGrateContrast = obj.surroundGrateContrast(obj.counter);
%                     obj.currentSurroundMeanContrast = 0;
%                 case 1
%                     obj.stimulusTag = 's_grate_none';
%                     obj.currentCenterGrateContrast = 0;
%                     obj.currentSurroundGrateContrast = obj.surroundGrateContrast(obj.counter);
%                     obj.currentSurroundMeanContrast = 0;
%             end
            
            currentCenterGrateContrast = obj.sequence(obj.counter,1);
            currentSurroundGrateContrast = obj.sequence(obj.counter,2);

            epoch.addParameter('stimulusTag', obj.stimulusTag);
            epoch.addParameter('stimulusIndex', obj.stimIndex);
            epoch.addParameter('currentCenterGrateContrast', currentCenterGrateContrast);
            epoch.addParameter('currentSurroundGrateContrast', currentSurroundGrateContrast);
            epoch.addParameter('currentSurroundMeanContrast', obj.surroundMeanContrast);
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity);
            
            spotDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.spotDiameter);
            annulusInnerDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.annulusInnerDiameter);
            surroundGrateBarSizePix = obj.rig.getDevice('Stage').um2pix(obj.surroundGrateBarSize);
            centerGrateBarSizePix = obj.rig.getDevice('Stage').um2pix(obj.centerGrateBarSize);
            
            currentCenterGrateContrast = obj.sequence(obj.counter,1);
            currentSurroundGrateContrast = obj.sequence(obj.counter,2);
            
            disp([currentCenterGrateContrast currentSurroundGrateContrast])

            % Create spot stimulus.
            if currentCenterGrateContrast == 0
                spot = stage.builtin.stimuli.Ellipse();
                spot.color = obj.backgroundIntensity + obj.backgroundIntensity * obj.spotContrast;
                spot.radiusX = spotDiameterPix/2;
                spot.radiusY = spotDiameterPix/2;
                spot.position = canvasSize/2;
                p.addStimulus(spot);
                
                %hide during pre & post
                spotVisible = stage.builtin.controllers.PropertyController(spot, 'visible', ...
                    @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                p.addController(spotVisible);
            end
            
            % Create grate stimulus.
            if currentCenterGrateContrast ~= 0
                spot = stage.builtin.stimuli.Grating('square'); %square wave grating
                spot.size = [spotDiameterPix spotDiameterPix];
                spot.position = canvasSize/2;
                spot.spatialFreq = 1/(2*centerGrateBarSizePix); %convert from bar width to spatial freq
                spot.color = 2*obj.backgroundIntensity;
                spot.contrast = currentCenterGrateContrast;
                %calc to apply phase shift s.t. a contrast-reversing boundary
                %is in the center regardless of spatial frequency. Arbitrarily
                %say boundary should be positve to right and negative to left
                %crosses x axis from neg to pos every period from 0
                zeroCrossings = 0:(spot.spatialFreq^-1):spot.size(1);
                offsets = zeroCrossings-spot.size(1)/2; %difference between each zero crossing and center of texture, pixels
                [shiftPix, ~] = min(offsets(offsets>0)); %positive shift in pixels
                phaseShift_rad = (shiftPix/(spot.spatialFreq^-1))*(2*pi); %phaseshift in radians
                phaseShift = 360*(phaseShift_rad)/(2*pi); %phaseshift in degrees
                spot.phase = phaseShift; %keep contrast reversing boundary in center
                p.addStimulus(spot);
                
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = canvasSize/2;
                aperture.color = obj.backgroundIntensity;
                aperture.size = [max(canvasSize) max(canvasSize)];
                mask = stage.core.Mask.createCircularAperture(spotDiameterPix/max(canvasSize), 1024); %circular aperture
                aperture.setMask(mask);
                p.addStimulus(aperture); %add aperture
                
                %hide during pre & post
                spotVisible = stage.builtin.controllers.PropertyController(spot, 'visible', ...
                    @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                p.addController(spotVisible);
                
            end

            %make grating in surround
            grate = stage.builtin.stimuli.Grating('square'); %square wave grating
            grate.size = 2.*[max(canvasSize) max(canvasSize)];
            grate.position = canvasSize/2;
            grate.spatialFreq = 1/(2*surroundGrateBarSizePix); %convert from bar width to spatial freq
            grate.color = 2*obj.backgroundIntensity;
            grate.contrast = currentSurroundGrateContrast;
            zeroCrossings = 0:(grate.spatialFreq^-1):grate.size(1);
            offsets = zeroCrossings-grate.size(1)/2; %difference between each zero crossing and center of texture, pixels
            [shiftPix, ~] = min(offsets(offsets>0)); %positive shift in pixels
            phaseShift_rad = (shiftPix/(grate.spatialFreq^-1))*(2*pi); %phaseshift in radians
            phaseShift = 360*(phaseShift_rad)/(2*pi); %phaseshift in degrees
            grate.phase = phaseShift; %keep contrast reversing boundary in center

            grateMask = stage.core.Mask.createCircularAperture(annulusInnerDiameterPix/(2*max(canvasSize)), 1024); %circular aperture
            grate.setMask(grateMask);
            p.addStimulus(grate); %add grating to the presentation
            grateVisible = stage.builtin.controllers.PropertyController(grate, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(grateVisible);
            
            function m = createDistanceMatrix(size)
                step = 2 / (size - 1);
                [xx, yy] = meshgrid(-1:step:1, -1:step:1);
                m = sqrt(xx.^2 + yy.^2);
            end
            
            obj.counter = obj.counter+1;
        end
        
        function [grateMean] = getGrateMean(obj,time)
            
            grateMean=2*obj.backgroundIntensity;
            if time>obj.preTime/1e3 && time< (obj.preTime+obj.stimTime)/1e3
                grateMean=2*obj.backgroundIntensity*(1+obj.currentSurroundMeanContrast);
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