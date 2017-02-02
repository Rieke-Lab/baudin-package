classdef StrfFigure < symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
        ampDevice
        frameMonitor
        stageDevice
        recordingType
        preTime
        stimTime
        frameDwell
        seedID
        binaryNoise
        filterLength
        frequencyCutoffFraction
        filterIntegrationTime
    end
    
    properties (Access = private)
        axesHandle
        imHandle
        noiseStream
        filterAverage
        epochCount
        lightCrafterFlag
    end
    
    methods
        
        function obj = StrfFigure(ampDevice, frameMonitor, stageDevice, varargin)
            obj.ampDevice = ampDevice;
            obj.frameMonitor = frameMonitor;
            obj.stageDevice = stageDevice;
            ip = inputParser();
            ip.addParameter('recordingType', [], @(x)ischar(x));
            ip.addParameter('preTime', [], @(x)isvector(x));
            ip.addParameter('stimTime', [], @(x)isvector(x));
            ip.addParameter('frameDwell', [], @(x)isvector(x));
            ip.addParameter('seedID', 'noiseSeed', @(x)ischar(x));
            ip.addParameter('binaryNoise', true, @(x)islogical(x));
            ip.addParameter('FilterLength', 800, @(x) isnumeric(x));
            ip.addParameter('FrequencyCutoffFraction', 0.8, @(x) isnumeric(x) && x < 1);
            ip.addParameter('FilterIntegrationTime', 120, @(x) isnumeric(x));
            ip.parse(varargin{:});
            
            obj.recordingType = ip.Results.recordingType;
            obj.preTime = ip.Results.preTime;
            obj.stimTime = ip.Results.stimTime;
            obj.frameDwell = ip.Results.frameDwell;
            obj.seedID = ip.Results.seedID;
            obj.binaryNoise = ip.Results.binaryNoise;
            obj.filterLength = ip.Results.FilterLength;
            obj.frequencyCutoffFraction = ip.Results.FrequencyCutoffFraction;
            obj.filterIntegrationTime = ip.Results.FilterIntegrationTime;
            % determine device type
            if isa(obj.stageDevice,'edu.washington.riekelab.devices.LightCrafterDevice')
                obj.lightCrafterFlag = 1;
            else % OLED stage device
                obj.lightCrafterFlag = 0;
            end
            
            obj.epochCount = 0;
            obj.filterAverage = 0;
            obj.createUi();
        end
        
        function createUi(obj)
            import appbox.*;
            toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
            playStrfButton = uipushtool( ...
                'Parent', toolbar, ...
                'TooltipString', 'Play Strf movie', ...
                'Separator', 'on', ...
                'ClickedCallback', @obj.onSelectedPlayStrf);
            setIconImage(playStrfButton, symphonyui.app.App.getResource('icons/view_only.png'));
            
            obj.axesHandle = axes( ...
                'Parent', obj.figureHandle, ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle, '');
            ylabel(obj.axesHandle, '');
            
            
            obj.figureHandle.Name ='STRF';
        end
        
        function handleEpoch(obj, epoch)
            obj.epochCount = obj.epochCount + 1;
            
            % load data
            sampleRate = epoch.getResponse(obj.ampDevice).sampleRate.quantityInBaseUnits;
            response = obj.CollectAndPreprocessResponse(epoch, sampleRate);
            
            % get frame times
            frameRate = obj.stageDevice.getMonitorRefreshRate();
            % updateRate = (frameRate / obj.frameDwell);
            frameMonResponse = epoch.getResponse(obj.frameMonitor).getData();
            frameTimes = edu.washington.riekelab.turner.utils.getFrameTiming(frameMonResponse, obj.lightCrafterFlag);
            
            % crop response to remove anything before stimulus began
            preFrames = frameRate * (obj.preTime / 1000);
            firstStimFrameFlip = frameTimes(preFrames + 1);
            response = response(firstStimFrameFlip:end);
            
            % figure out stim frames and get average response per frame
            stimFrames = round(frameRate * (obj.stimTime / 1e3));
            ptsPerFrame = floor((obj.stimTime * sampleRate / 1e3) / stimFrames);
            
            % note, this tosses out a handful of points (on the order of
            % tens) - if issues arrise, consider changing
            ptsToUse = stimFrames * ptsPerFrame;
            responsePerFrame = mean(reshape(response(1:ptsToUse), [ptsPerFrame, stimFrames]), 1);
            
            % recreate stimulus
            stimulus = obj.RegenerateStimulus(epoch, frameRate);
            
            % compute filters, then normalize
            filterPts = (obj.filterLength / 1000) * frameRate;
            currFilters = obj.ComputeFilters(stimulus, responsePerFrame, filterPts, frameRate);
            currFilters = currFilters / max(currFilters(:));
            
            % update filter average
            obj.filterAverage = ((obj.epochCount - 1) * obj.filterAverage + currFilters) / obj.epochCount;
            
            % apply updated integrated average to plot
            integrationPts = round(obj.filterIntegrationTime * frameRate / 1e3);
            disp(integrationPts);
            disp(size(obj.filterAverage));
            obj.UpdateImage(sum(obj.filterAverage(:, :, 1:integrationPts), 3));
        end
        
        function response = CollectAndPreprocessResponse(obj, epoch, sampleRate)
            response = epoch.getResponse(obj.ampDevice).getData();
            prePts = sampleRate * obj.preTime / 1000;
            
            if strcmp(obj.recordingType,'extracellular') %spike recording
                % convert response to vector of spikes
                spikes = edu.washington.riekelab.turner.utils.spikeDetectorOnline(response);
                response = zeros(size(response));
                response(spikes.sp) = 1;
                
            else %intracellular - Vclamp
                % zero baseline and give response correct polarity
                response = response - mean(response(1:prePts));
                if strcmp(obj.recordingType,'exc') %measuring exc
                    polarity = -1;
                elseif strcmp(obj.recordingType,'inh') %measuring inh
                    polarity = 1;
                end
                response = polarity * response;
            end
        end
        
        function stimulus = RegenerateStimulus(obj, epoch, frameRate)
            currentNoiseSeed = epoch.parameters(obj.seedID);
            numChecksX = epoch.parameters('numChecksX');
            numChecksY = epoch.parameters('numChecksY');
            
            stimFrames = round(frameRate * (obj.stimTime / 1e3));
            numUpdates = floor(stimFrames / obj.frameDwell);
            
            % reset random stream to recover stim trajectories
            obj.noiseStream = RandStream('mt19937ar', 'Seed', currentNoiseSeed);
            
            stimulus = zeros(numChecksY, numChecksX, stimFrames);
            for i = 1:numUpdates
                if obj.binaryNoise
                    frame = double(obj.noiseStream.rand(numChecksY, numChecksX) > 0.5);
                else
                    frame = obj.noiseStream.randn(numChecksY, numChecksX);
                end
                
                for j = 1:obj.frameDwell
                    stimulus(:, :, (i - 1) * obj.frameDwell + j) = frame;
                end
            end
        end
        
        function filters = ComputeFilters(obj, stimulus, response, filterPts, frameRate)
            % figure out cutoff in frequency domain, convert to pts
            cutoffFreq = obj.frequencyCutoffFraction * frameRate;
            cutoffPts = round(cutoffFreq / (frameRate / length(stimulus)));
            
            % calculate filters in frequency domain, do cutoff
            filterFFTs = bsxfun(@times, conj(fft(stimulus, [], 3)), fft(reshape(response, [1 1 numel(response)]), [], 3));
            filterFFTs(:, :, 1) = 0;
            if cutoffFreq < frameRate / 2
                filterFFTs(:, :, 1 + cutoffPts:size(filterFFTs, 3) - cutoffPts) = 0;
            end
            
            % return to time domain and trim to specified length
            filters = real(ifft(filterFFTs, [], 3));
            filters = filters(:, :, 1:filterPts);
        end
        
        function UpdateImage(obj, toShow)
            if isempty(obj.imHandle)
                obj.imHandle = imagesc(imgaussfilt(toShow, 2),...
                    'Parent', obj.axesHandle);
                title(obj.axesHandle, 'integrated linear filters');
                colormap(obj.axesHandle, gray)
            else
                set(obj.imHandle, 'CData', toShow);
            end
        end
    end
    
    methods (Access = private)
        function onSelectedPlayStrf(obj, ~, ~)
            implay(obj.filterAverage);
        end
    end
    
end

