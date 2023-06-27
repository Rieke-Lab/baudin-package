classdef ConeSpecificDisplayAdaptationAndLinearization <edu.washington.riekelab.protocols.RiekeLabProtocol
    properties
        % the values could be drawn from Isomerization converter on each
        % rig
        apertureDiameter=200; % um
        backgroundDiameter=800; % um
        redChannelIsomPerUnitL=20000;   % isom
        redChannelIsomPerUnitM=10000;
        redChannelIsomPerUnitS=10000;
        blueChannelIsomPerUnitL=20000;
        blueChannelIsomPerUnitM=10000;
        blueChannelIsomPerUnitS=10000;
        greenChannelIsomPerUnitL=20000;
        greenChannelIsomPerUnitM=10000;
        greenChannelIsomPerUnitS=10000;
        constantConeBackground=2000;
        coneOnChangingBackgroundToStim=edu.washington.riekelab.rieke.protocols.ConeSpecificDisplayAdaptationAndLinearization.M_CONE;
        numberOfAverage=uint16(5);
        onlineAnalysis='extracellular';
        amp;
        inputStimulusFrameRate=60;
    end
    properties(Hidden)
        coneOnConstantToStimulateType = symphonyui.core.PropertyType( ...
            'char', 'row', edu.washington.riekelab.rieke.protocols.ConeSpecificDisplayAdaptationAndLinearization.CONE_TYPES_LMS)
        coneForChangingBackgroundsType = symphonyui.core.PropertyType( ...
            'char', 'row', edu.washington.riekelab.rieke.protocols.ConeSpecificDisplayAdaptationAndLinearization.CONE_TYPES_LMS)
        ampType
        onlineAnalysisType=symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'});
        ResourceFolderPath = 'C:\Users\Public\Documents\baudin-package\+edu\+washington\+riekelab\+baudin\+resources\'
        stimulusDataPath = 'grating_plus_mean'; % string of path to
        stimulusDurationSeconds
        currentStimuli
        stimuli
        backgroundIsomerizations
        rgbWaves
    end
    properties (Hidden, Dependent)
        rgbToLms
        lmsToRgb
    end
    properties (Hidden,Constant)
        S_CONE = 's cone';
        M_CONE = 'm cone';
        L_CONE = 'l cone';
        CONE_TYPES_LMS = {edu.washington.riekelab.rieke.protocols.ConeSpecificDisplayAdaptationAndLinearization.L_CONE, ...
            edu.washington.riekelab.rieke.protocols.ConeSpecificDisplayAdaptationAndLinearization.M_CONE, ...
            edu.washington.riekelab.rieke.protocols.ConeSpecificDisplayAdaptationAndLinearization.S_CONE};
    end
    
    methods
        function value=get.rgbToLms(obj)
            value=[obj.redChannelIsomPerUnitL obj.greenChannelIsomPerUnitL obj.blueChannelIsomPerUnitL; ...;
                obj.redChannelIsomPerUnitM obj.greenChannelIsomPerUnitM obj.blueChannelIsomPerUnitM; ...;
                obj.redChannelIsomPerUnitS obj.greenChannelIsomPerUnitS obj.blueChannelIsomPerUnitS];
        end
        function value=get.lmsToRgb(obj)
            value=inv(obj.rgbToLms);
        end
        
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function constructStimuli(obj)
            obj.stimuli = struct;
            obj.stimuli.names = {'stepCorrected', ...
                'stepUncorrected', ...
                'spotCorrected', ...
                'spotUncorrected' ...
                'spotCorrectedLowContrast' ...
                'spotUncorrectedLowContrast' ...
                'gratingCorrected' ...
                'gratingUncorrected'};

            stimulusData = load(strcat(obj.ResourceFolderPath, obj.stimulusDataPath));
            
            obj.backgroundIsomerizations = stimulusData.stepCorrected(1);            
            obj.stimuli.lookup = containers.Map(obj.stimuli.names, ...
                {{stimulusData.stepCorrected, stimulusData.stepCorrected, stimulusData.stepCorrected}, ...
                {stimulusData.stepUncorrected, stimulusData.stepUncorrected, stimulusData.stepUncorrected}, ...
                {stimulusData.stepCorrected, stimulusData.spotCorrected, stimulusData.spotCorrected}, ...
                {stimulusData.stepUncorrected, stimulusData.spotUncorrected, stimulusData.spotUncorrected}, ...
                {stimulusData.stepCorrected, stimulusData.spotCorrectedLowContrast, stimulusData.spotCorrectedLowContrast}, ...
                {stimulusData.stepUncorrected, stimulusData.spotUncorrectedLowContrast, stimulusData.spotUncorrectedLowContrast}, ...
                {stimulusData.stepCorrected, stimulusData.spotCorrected, stimulusData.spotNegCorrected}, ...
                {stimulusData.stepUncorrected, stimulusData.spotUncorrected, stimulusData.spotNegUncorrected}});

            obj.stimulusDurationSeconds = (numel(stimulusData.stepCorrected)) ...
                / obj.inputStimulusFrameRate;
        end
        
        function [lmsWaves] = getLmsWaves(obj, adaptingWaveform)
            lmsTypes = edu.washington.riekelab.rieke.protocols.ConeSpecificDisplayAdaptationAndLinearization.CONE_TYPES_LMS;
            lmsWaves =  repmat(obj.constantConeBackground * cellfun(@(x) ~strcmp(x, obj.coneOnChangingBackgroundToStim), ...,
                lmsTypes)',1,length(adaptingWaveform))+ ...,
                + bsxfun(@times, adaptingWaveform',cellfun(@(x) strcmp(x, obj.coneOnChangingBackgroundToStim), lmsTypes)');
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            obj.constructStimuli();
            colors = edu.washington.riekelab.turner.utils.pmkmp(length(obj.stimuli.names)+2,'CubicYF');
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.turner.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'groupBy',{'stimulus type'},...
                'sweepColor',colors);
            obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            epochNumber = obj.numEpochsCompleted;
            index=mod(epochNumber,length(obj.stimuli.names))+1;
            obj.currentStimuli = obj.stimuli.lookup(obj.stimuli.names{index});
            
            ampDevice = obj.rig.getDevice(obj.amp);
            duration = obj.stimulusDurationSeconds;
            epoch.addDirectCurrentStimulus(ampDevice, ampDevice.background, duration, obj.sampleRate);
            epoch.addParameter('stimulus type', obj.stimuli.names{index});
            epoch.addResponse(ampDevice);   
            lmsWaves=obj.getLmsWaves(obj.currentStimuli{1});
            obj.rgbWaves=obj.lmsToRgb*lmsWaves;
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            rgbBackgrounds=obj.lmsToRgb * obj.getLmsWaves(obj.currentStimuli{1});
            rgbBackgrounds=rgbBackgrounds(:,1);
            leftStimulus = obj.getLeftStimulus();
            rightStimulus = obj.getRightStimulus();
            backgroundStimulus = obj.getBackgroundStimulus();
            
            %convert from microns to pixels...
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            
            p = stage.core.Presentation(obj.stimulusDurationSeconds); %create presentation of specified duration
            p.setBackgroundColor(rgbBackgrounds); % Set background intensity
            
            % step background spot for specified time
            spotDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.backgroundDiameter);
            background = stage.builtin.stimuli.Ellipse();
            background.radiusX = spotDiameterPix/2;
            background.radiusY = spotDiameterPix/2;
            background.position = canvasSize/2;
            p.addStimulus(background);
            backgroundMean = stage.builtin.controllers.PropertyController(background, 'color',...
                @(state)getRegionMean(obj, backgroundStimulus, state.frame));
            p.addController(backgroundMean); %add the controller
            
            leftRectangle = stage.builtin.stimuli.Rectangle();
            leftRectangle.size = apertureDiameterPix .* [0.5 1];
            leftRectangle.position = canvasSize .* [0.5 0.5] + [apertureDiameterPix/4 0];
            leftRectangle.color = obj.isomerizationsToColor(leftStimulus(1));
            p.addStimulus(leftRectangle);
            leftMean = stage.builtin.controllers.PropertyController(leftRectangle, 'color',...
                @(state)getRegionMean(obj, leftStimulus, state.frame));
            p.addController(leftMean);
            
            rightRectangle = stage.builtin.stimuli.Rectangle();
            rightRectangle.size = apertureDiameterPix .* [0.5 1];
            rightRectangle.position = canvasSize .* [0.5 0.5] - [apertureDiameterPix/4 0];
            rightRectangle.color = obj.isomerizationsToColor(rightStimulus(1));
            p.addStimulus(rightRectangle);
            rightMean = stage.builtin.controllers.PropertyController(rightRectangle, 'color',...
                @(state)getRegionMean(obj, rightStimulus, state.frame));
            p.addController(rightMean);
            
            aperture = stage.builtin.stimuli.Rectangle();
            aperture.position = canvasSize/2;
            aperture.size = [apertureDiameterPix, apertureDiameterPix];
            mask = stage.core.Mask.createCircularAperture(1, 1024); %circular aperture
            aperture.setMask(mask);
            p.addStimulus(aperture); %add aperture
            apertureMean = stage.builtin.controllers.PropertyController(aperture, 'color',...
                @(state)getRegionMean(obj, backgroundStimulus, state.frame));
            p.addController(apertureMean); %add the controller
            
            % mean of background spot
            function m = getRegionMean(obj, adaptingWaveform, currentFrame)
                m=obj.lmsToRgb*obj.getLmsWaves(adaptingWaveform);
                m = m(currentFrame+1);
            end
            
        end
        
        function stimulus = getBackgroundStimulus(obj)
            stimulus = obj.currentStimuli{1};
        end
        
        function stimulus = getLeftStimulus(obj)
            stimulus = obj.currentStimuli{2};
        end
        
        function stimulus = getRightStimulus(obj)
            stimulus = obj.currentStimuli{3};
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverage * numel(obj.stimuli.names);
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverage * numel(obj.stimuli.names);
        end
    end
end