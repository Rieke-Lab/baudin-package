% make 3 subplots, arranged horizontally
%    left: plot of average membrane potential across time for
%        voltage measurements
%    center: plot of most recent specified number of led pulses to overlay
%    right: plot of response size over time

classdef PerforatedPatchMonitoringFigure < symphonyui.core.FigureHandler
    properties (Access = private)        
        responseDevice
        stimulusDevice
        ledPulsesToOverlay
        
        membranePotentialPlotAxes
        ledPulseResponsesPlotAxes
        flashResponseSizePlotAxes
        
        membranePotentialScatter
        ledPulseResponsesLines
        flashResponseSizeScatter
    end
    
    methods
        
        function obj = PerforatedPatchMonitoringFigure(responseDevice, stimulusDevice, ledPulsesToOverlay)
            obj.responseDevice = responseDevice;
            obj.stimulusDevice = stimulusDevice;
            obj.ledPulsesToOverlay = ledPulsesToOverlay;
            obj.createUi();
        end
        
        function createUi(obj)
            % scatter of membrane potentials
            obj.membranePotentialPlotAxes = subplot(1,3,1,...
                'Parent',obj.figureHandle,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            obj.membranePoentialAxes.XLabel.String = 'epoch number';
            obj.membranePotentialPlotAxes.YLabel.String = 'average voltage (mV)';
            obj.membranePotentialScatter = scatter([], [], ...
                'Parent', obj.membranePotentialPlotAxes, ...
                'SizeData', 20, ...
                'Marker', '.', ...
                'MarkerEdgeColor', [0.2 0.2 1], ...
                'MarkerFaceColor', [0.2 0.2 1]);
            
            % overlaid flash response traces
            obj.ledPulseResponsesPlotAxes = subplot(1,3,2,...
                'Parent',obj.figureHandle,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            obj.ledPulseResponsesPlotAxes.XLabel.String = 'time (ms)';
            obj.ledPulseResponsesPlotAxes.YLabel.String = 'flash response (mV)';
            obj.ledPulseResponsesLines = gobjects(obj.ledPulsesToOverlay, 0);
            
            % scatter of flash response sizes
            obj.flashResponseSizePlotAxes = subplot(1,3,3,...
                'Parent',obj.figureHandle,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            obj.flashResponseSizePlotAxes.XLabel.String = 'epoch number';
            obj.flashResponseSizePlotAxes.YLabel.String = 'flash response amplitude (mV)';
            obj.flashResponseSizeScatter = scatter([], [], ...
                'Parent', obj.flashResponseSizePlotAxes, ...
                'SizeData', 20, ...
                'Marker', '.', ...
                'MarkerEdgeColor', [0.2 0.2 1], ...
                'MarkerFaceColor', [0.2 0.2 1]);
        end
        
        
        function handleEpoch(obj, epoch)
            response = epoch.getResponse(obj.responseDevice).getData();
            
            if epoch.parameters('isLedPulseEpoch')
                stimulus = epoch.getStimulus(obj.stimulusDevice);
                
                preTime = stimulus.parameters('preTime');
                sampleRate = stimulus.sampleRate.quantityInBaseUnits;
                prePts = preTime * sampleRate / 1e3;
                
                zeroedResponse = epochTrace - mean(response(1:prePts));
                timeVector = ((0:numel(response) - 1) - prePts) * 1e3 / sampleRate;

                obj.updateLedPulseResponseAxes(zeroedResponse, timeVector);
                obj.updateFlashResponseSizeAxes(zeroedResponse);
            else
                obj.updateMembranePotentialAxes(response);
            end
        end
        
        function updateMembranePotentialAxes(obj, response)
            obj.addPointToScatter(obj.membranePotentialScatter, mean(response));
        end
        
        function updateLedPulseResponsesAxes(obj, zeroedResponse, timeVector)
            obj.ledPulseResponsesLines = [line(timeVector, zeroedResponse) ...
                obj.ledPulseResponsesLines(1:end - 1)];
            legend(obj.ledPulseResponseLines(1:numel(obj.ledPulseResponseLines)), ...
                arrayfun(@(x) num2str(x), (0:-1:-numel(obj.ledPulseResponsesLines) + 1), 'UniformOutput', false), ...
                'Box', 'off')
        end
        
        function updateFlashResponseSizeAxes(obj, zeroedResponse)
            obj.addPointToScatter(obj.flashResponseSizeScatter, min(zeroedResponse));
        end
        
        function addPointToScatter(scatterToUdate, newData)
            currYData = obj.scatterToUdate.YData;
            set(scatterToUdate, ...
                'XData', (1:numel(currYData) + 1), ...
                'YData', [currYData newData]);
        end
        
    end
    
end

