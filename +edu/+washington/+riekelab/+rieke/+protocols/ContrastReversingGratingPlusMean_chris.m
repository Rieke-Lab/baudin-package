classdef ContrastReversingGratingPlusMean_chris< edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        preTime = 1000 % ms
        stimTime = 1000 % ms
        tailTime = 2000 % ms
        contrast = 0.9 % relative to mean (0-1)
        temporalFrequency = 6 % Hz
        apertureDiameter = 200; % um
        backgroundDiameter=600; % um
        barWidth = [1 2 3 100] % um
        backgroundIntensity = 0.05 % (0-1)
        stepIntensity = 0.5
        onlineAnalysis = 'none'
        numberOfAverages = uint16(20) % number of epochs to queue
        amp
    end
    
    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        currentBarWidth
        stimulusTag
    end
    
    properties (Hidden, Transient)
        analysisFigure
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        
        function CRGanalysis(obj, ~, epoch) %online analysis function
            response = epoch.getResponse(obj.rig.getDevice(obj.amp));
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            
            axesHandle = obj.analysisFigure.userData.axesHandle;
            trialCounts = obj.analysisFigure.userData.trialCounts;
            F1 = obj.analysisFigure.userData.F1;
            F2 = obj.analysisFigure.userData.F2;
            
            if strcmp(obj.onlineAnalysis,'extracellular') %spike recording
                %take (prePts+1:prePts+stimPts)
                epochResponseTrace = epochResponseTrace((sampleRate*obj.preTime/1000)+1:(sampleRate*(obj.preTime + obj.stimTime)/1000));
                %count spikes
                S = edu.washington.riekelab.turner.utils.spikeDetectorOnline(epochResponseTrace);
                epochResponseTrace = zeros(size(epochResponseTrace));
                epochResponseTrace(S.sp) = 1; %spike binary
                
            else %intracellular - Vclamp
                epochResponseTrace = epochResponseTrace-mean(epochResponseTrace(1:sampleRate*obj.preTime/1000)); %baseline
                %take (prePts+1:prePts+stimPts)
                epochResponseTrace = epochResponseTrace((sampleRate*obj.preTime/1000)+1:(sampleRate*(obj.preTime + obj.stimTime)/1000));
            end
            
            L = length(epochResponseTrace); %length of signal, datapoints
            X = abs(fft(epochResponseTrace));
            X = X(1:L/2);
            f = sampleRate*(0:L/2-1)/L; %freq - hz
            [~, F1ind] = min(abs(f-obj.temporalFrequency)); %find index of F1 and F2 frequencies
            [~, F2ind] = min(abs(f-2*obj.temporalFrequency));
            
            F1power = 2*X(F1ind); %pA^2/Hz for current rec, (spikes/sec)^2/Hz for spike rate
            F2power = 2*X(F2ind); %double b/c of symmetry about zero
            
            barInd = find(obj.currentBarWidth == obj.barWidth);
            trialCounts(barInd) = trialCounts(barInd) + 1;
            F1(barInd) = F1(barInd) + F1power;
            F2(barInd) = F2(barInd) + F2power;
            
            cla(axesHandle);
            h1 = line(obj.barWidth, F1./trialCounts, 'Parent', axesHandle);
            set(h1,'Color','g','LineWidth',2,'Marker','o');
            h2 = line(obj.barWidth, F2./trialCounts, 'Parent', axesHandle);
            set(h2,'Color','r','LineWidth',2,'Marker','o');
            hl = legend(axesHandle,{'F1','F2'});
            xlabel(axesHandle,'Bar width (um)')
            ylabel(axesHandle,'Amplitude')
            
            obj.analysisFigure.userData.trialCounts = trialCounts;
            obj.analysisFigure.userData.F1 = F1;
            obj.analysisFigure.userData.F2 = F2;
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            
            index = mod(obj.numEpochsCompleted, length(obj.barWidth)) + 1;
            obj.currentBarWidth = obj.barWidth(index);
            
            switch index
                case 1
                    obj.stimulusTag='stepSpot';
                case 2
                    obj.stimulusTag='modulatedSpot';
                case 3
                    obj.stimulusTag='modulatedGrating';
                case 4
                    obj.stimulusTag='correlatedSurround';  % grating in the surround
            end
            epoch.addParameter('currentBarWidth', obj.currentBarWidth);
            epoch.addParameter('stimulusTag', obj.stimulusTag);
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            if length(obj.barWidth) > 1
                colors = edu.washington.riekelab.turner.utils.pmkmp(length(obj.barWidth)+2,'CubicYF');
            else
                colors = [0 0 0];
            end
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            if strcmp(obj.onlineAnalysis,'extracellular')
                psth=true;
            else
                psth=false;
            end
            obj.showFigure('edu.washington.riekelab.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp),'psth',psth,...
                'groupBy',{'currentBarWidth'},...
                'sweepColor',colors);
            obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            if ~strcmp(obj.onlineAnalysis,'none')
                % custom figure handler
                if isempty(obj.analysisFigure) || ~isvalid(obj.analysisFigure)
                    obj.analysisFigure = obj.showFigure('symphonyui.builtin.figures.CustomFigure', @obj.CRGanalysis);
                    f = obj.analysisFigure.getFigureHandle();
                    set(f, 'Name', 'CRGs');
                    obj.analysisFigure.userData.trialCounts = zeros(size(obj.barWidth));
                    obj.analysisFigure.userData.F1 = zeros(size(obj.barWidth));
                    obj.analysisFigure.userData.F2 = zeros(size(obj.barWidth));
                    obj.analysisFigure.userData.axesHandle = axes('Parent', f);
                else
                    obj.analysisFigure.userData.trialCounts = zeros(size(obj.barWidth));
                    obj.analysisFigure.userData.F1 = zeros(size(obj.barWidth));
                    obj.analysisFigure.userData.F2 = zeros(size(obj.barWidth));
                end
                
            end
            
        end
        
        
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            %convert from microns to pixels...
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            currentBarWidthPix = obj.rig.getDevice('Stage').um2pix(obj.barWidth(end));
            outerDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.backgroundDiameter);
            innerDiameterPix= obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter+50);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(obj.backgroundIntensity); % Set background intensity
            
            index = mod(obj.numEpochsCompleted, length(obj.barWidth)) + 1;
            
            % create center grating
            if index~=2
                centerGrate=createGrate(obj.backgroundIntensity,canvasSize, apertureDiameterPix,currentBarWidthPix);
            else
                centerGrate=createGrate(obj.backgroundIntensity,canvasSize, apertureDiameterPix,apertureDiameterPix);
                centerGrate.phase=0;
            end
            
            % control the pattern of stimuli through contrast, =0 to be spot
            % pattern
            if index==1
                centerGrateContrast = stage.builtin.controllers.PropertyController(centerGrate, 'contrast', @(state) 0);
            else
                centerGrateContrast = stage.builtin.controllers.PropertyController(centerGrate, 'contrast',...
                    @(state)getGrateContrast( obj, state.time));
            end
            % control the luminance trajectory
            
            centerGrateMean = stage.builtin.controllers.PropertyController(centerGrate, 'color',...
                @(state)getGrateMean(obj, state.time));
            
            % Create aperture
            aperture = stage.builtin.stimuli.Rectangle();
            aperture.position =  canvasSize/2;
            aperture.color = obj.backgroundIntensity;
            aperture.size = [ apertureDiameterPix, apertureDiameterPix];
            mask = stage.core.Mask.createCircularAperture(1, 1024); %circular aperture
            aperture.setMask(mask);
            
            p.addStimulus(centerGrate);
            p.addController(centerGrateContrast);
            p.addController(centerGrateMean);
            p.addStimulus(aperture);
            
            % make sure turns off at end
            centerGrateVisible = stage.builtin.controllers.PropertyController(centerGrate, 'visible', ...
                @(state)state.time < (obj.preTime + obj.stimTime + obj.tailTime - 50) * 1e-3);
            p.addController(centerGrateVisible);
            
            
            % create the surround grating stimuli
            surroundGrate=createGrate(obj.backgroundIntensity, canvasSize,  outerDiameterPix, currentBarWidthPix);
            mask = stage.core.Mask.createAnnulus( innerDiameterPix/ outerDiameterPix, 1,1024);
            surroundGrate.setMask(mask);
            % control the contrast, set to 0 for step spot
            if index>3
                surroundGrateContrast = stage.builtin.controllers.PropertyController(surroundGrate, 'contrast',...
                    @(state)getGrateContrast( obj, state.time)); % low contrast
            else
                surroundGrateContrast = stage.builtin.controllers.PropertyController(surroundGrate, 'contrast',...
                    @(state) 0);
            end
            
            
            % dictate the luminance trajectory
            
            surroundGrateMean = stage.builtin.controllers.PropertyController(surroundGrate, 'color',...
                @(state)getGrateMean(obj, state.time));
            
            p.addStimulus(surroundGrate);
            p.addController(surroundGrateContrast); %add the controller
            p.addController(surroundGrateMean); %add the controller
            
            % make sure turns off at end
            surroundGrateVisible = stage.builtin.controllers.PropertyController(surroundGrate, 'visible', ...
                @(state)state.time < (obj.preTime + obj.stimTime + obj.tailTime - 50) * 1e-3);
            p.addController(surroundGrateVisible);
            
            function [grate] = createGrate(backgroundIntensity,canvasSize,grateSize,currentBarWidthPix)
                grate = stage.builtin.stimuli.Grating('square'); %square wave grating
                grate.size = [grateSize, grateSize];
                grate.position =  canvasSize/2;
                grate.spatialFreq = 1/(2* currentBarWidthPix); %convert from bar width to spatial freq
                grate.color = 2*backgroundIntensity;
                zeroCrossings = 0:(grate.spatialFreq^-1):grate.size(1);
                offsets = zeroCrossings-grate.size(1)/2; %difference between each zero crossing and center of texture, pixels
                [shiftPix, ~] = min(offsets(offsets>0)); %positive shift in pixels
                phaseShift_rad = (shiftPix/(grate.spatialFreq^-1))*(2*pi); %phaseshift in radians
                phaseShift = 360*(phaseShift_rad)/(2*pi); %phaseshift in degrees
                grate.phase = phaseShift; %keep contrast reversing boundary in center
            end
            
            function c = getGrateContrast( obj,time)
                c =obj.contrast*sin(2 *pi* obj.temporalFrequency  * time);
            end
            % grating mean
            function m = getGrateMean(obj, time)
                m = obj.backgroundIntensity*2;
                if (time > obj.preTime/1e3 && time < (obj.preTime/1e3 + obj.stimTime/1e3))
                    m = obj.stepIntensity*2;
                end
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