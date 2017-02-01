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
            obj.lightCrafterFlag = obj.IsLightCrafter();
            
            obj.epochCount = 0;
            obj.filterAverage = 0;
            obj.createUi();
        end
        
        function tf = obj.IsLightCrafter(obj)
            % determine device type
            if isa(obj.stageDevice,'edu.washington.riekelab.devices.LightCrafterDevice')
                tf = 1;
            else % OLED stage device
                tf = 0;
            end
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
            response = obj.CollectAndPreprocessResponse(epoch);

            % get frame times
            frameRate = obj.stageDevice.getMonitorRefreshRate();
            updateRate = (frameRate / obj.frameDwell);
            frameMonResponse = epoch.getResponse(obj.frameMonitor).getData();
            frameTimes = edu.washington.riekelab.turner.utils.getFrameTiming(frameMonResponse, obj.lightCrafterFlag);
            
            % crop response to remove anything before stimulus began
            preFrames = frameRate * (obj.preTime / 1000);
            firstStimFrameFlip = frameTimes(preFrames + 1);
            response = response(firstStimFrameFlip:end);
            
            % figure out stim frames and get average response per frame
            stimFrames = round(frameRate * (obj.stimTime / 1e3));
            responsePerFrame = mean(reshape(response, [ stimFrames]), 1);
            
            % recreate stimulus
            stimulus = obj.RegenerateStimulus(epoch, frameRate);

            % compute filters, then normalize
            filterPts = (obj.filterLength / 1000) * updateRate;
            currFilters = obj.ComputeFilters(stimulus, responsePerFrame, filterPts, updateRate);
            currFilters = currFilters / max(currFilters(:));
            
            % update filter average
            obj.filterAverage = ((obj.epochCount - 1) * obj.filterAverage + currFilters) / obj.epochCount;
            
            % apply updated integrated average to plot
            obj.UpdateImage(sum(obj.filterAverage(:, :, 1:integrationPts)));
        end
        
        function response = CollectAndPreprocessResponse(obj, epoch)
            response = epoch.getResponse(obj.ampDevice).getData();
            sampleRate = epoch.getResponse(obj.ampDevice).sampleRate.quantityInBaseUnits;
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
        
        function stim = RegenerateStimulus(obj, epoch)
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
                    frame = obj.noiseStream.rand(numChecksY, numChecksX);
                else
                    frame = obj.noiseStream.randn(numChecksY, numChecksX);
                end
                
                for j = 1:obj.frameDwell
                    stimulus(:, :, (i - 1) * numUpdates + j:i * numUpdates) = frame;
                end
            end
        end
        
        function filters = ComputeFilters(obj, stim, resp, filterPts, updateRate)
            % figure out cutoff in frequency domain, convert to pts
            cutoffFreq = obj.frequencyCutoffFraction * updateRate;
            cutoffPts = round(cutoffFreq / (updateRate / length(stimulus)));
            
            % calculate filters in frequency domain, do cutoff
            filterFFTs = bsxfun(@times, fft(stim, [], 3), fft(reshape(resp, [1 1 numel(resp)]), [], 3));
            filterFFTs(:, :, 1 + cutoffPts:size(filterFFTs, 3) - cutoffPts) = 0;
            
            % return to time domain and trim to specified length
            filters = real(ifft(filterFFTs, [], 3));
            filters = filters(:, :, filterPts);
        end
        
        function UpdateImage(obj, toShow)
            if isempty(obj.imHandle)
                obj.imHandle = imagesc(toShow,...
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

