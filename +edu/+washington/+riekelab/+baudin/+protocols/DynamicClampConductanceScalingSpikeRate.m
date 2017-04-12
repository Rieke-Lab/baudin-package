classdef DynamicClampConductanceScalingSpikeRate < edu.washington.riekelab.protocols.RiekeLabProtocol
    properties
        gExcMultiplier = 1
        gInhMultiplier = 1
        
        excitatoryConductancePath = 'C:\Users\Jacob Baudin\Documents\baudin-package\+edu\+washington\+riekelab\+baudin\+resources\repeatedSeedNoiseConductances.mat'
        
        ExcReversal = 10;
        InhReversal = -70;
        
        nSPerV = 20;
        
        epochToUse = 1;
        
        amp
        numberOfAverages = uint16(5)
        interpulseInterval = 0.2
    end
    
    properties (Hidden)
        conductanceData
        ampType
        spikeRateFigure
        spikeRateAxes = [];
        spikeRateLine = [];
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            % load the conductances
            obj.conductanceData = load(obj.excitatoryConductancePath);
            
            obj.spikeRateFigure = obj.showFigure( ...
                'symphonyui.builtin.figures.CustomFigure', @obj.updateFigure);
            obj.initializeSpikeRateFigure();
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.turner.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.turner.figures.DynamicClampFigure',...
                obj.rig.getDevice(obj.amp), obj.rig.getDevice('Excitatory conductance'),...
                obj.rig.getDevice('Inhibitory conductance'), obj.rig.getDevice('Injected current'),...
                obj.ExcReversal, obj.InhReversal);
            
            %set the backgrounds on the conductance commands
            %0.05 V command per 1 nS conductance
            c = obj.conductanceData;
%             allPrePts = c.conductances(1:(c.preTime * c.sampleRate / 1e3), :);
            excBackground = obj.nSToVolts(mean(c.conductances(obj.epochToUse, :)) * obj.gExcMultiplier);
%             excBackground = obj.nSToVolts(mean(allPrePts(:)) * obj.gExcMultiplier);
            obj.rig.getDevice('Excitatory conductance').background = symphonyui.core.Measurement(excBackground, 'V');
        end
        
        function initializeSpikeRateFigure(obj)
            obj.spikeRateLine = [];
            obj.spikeRateFigure.getFigureHandle().Color = 'w';
            if ~isempty(obj.spikeRateAxes) && isvalid(obj.spikeRateAxes)
                cla(obj.spikeRateAxes);
            else
                obj.spikeRateAxes = axes('Parent', obj.spikeRateFigure.getFigureHandle());
            end
            obj.spikeRateAxes.XLabel.String = 'epoch number';
            obj.spikeRateAxes.YLabel.String = 'spike rate (Hz)';
            obj.spikeRateAxes.Title.String = 'spike rate monitor';
        end
        
        function updateFigure(obj, ~, epoch)
            response = epoch.getResponse(obj.rig.getDevice(obj.amp));
            epochTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            duration = numel(epochTrace) / sampleRate;
            
            spikes = edu.washington.riekelab.baudin.utils.spikeDetectorOnline(epochTrace);
            spikeCount = length(spikes.sp);
            spikeRate = spikeCount / duration;
            
            if isempty(obj.spikeRateLine)
                obj.spikeRateLine = plot(obj.spikeRateAxes, ...
                    1, spikeRate, ...
                    'LineWidth', 2, ...
                    'Color', [0.2 0.2 1]);
                text(obj.spikeRateAxes, ...
                    1, spikeRate * 1.1, ...
                    num2str(spikeRate));
            else
                epochNum = numel(obj.spikeRateLine.XData) + 1;
                set(obj.spikeRateLine, ...
                    {'XData', 'YData'}, ...
                    {(1:epochNum), [obj.spikeRateLine.YData spikeRate]});
                text(obj.spikeRateAxes, ...
                    epochNum, spikeRate * 1.3, ...
                    num2str(spikeRate));
            end
            obj.spikeRateAxes.XLabel.String = 'epoch number';
            obj.spikeRateAxes.YLabel.String = 'spike rate (Hz)';
            obj.spikeRateAxes.Title.String = 'spike rate monitor';
        end
        
        function stim = createConductanceStimulus(obj, conductanceType, conductance)
            % conductanceType is string: 'exc' or 'inh'
            gen = symphonyui.builtin.stimuli.WaveformGenerator();
            gen.sampleRate = obj.sampleRate;
            gen.units = 'V';
            
            if strcmpi(conductanceType,'exc')
                newConductanceTrace = obj.gExcMultiplier .* conductance; %nS
            elseif strcmpi(conductanceType,'inh')
                newConductanceTrace = obj.gInhMultiplier .* conductance; %nS
            end
            
            %map conductance (nS) to DAC output (V) to match expectation of
            %Arduino...
            % oftem, 200 nS = 10 V, 1 nS = 0.05 V
            mappedConductanceTrace = obj.nSToVolts(newConductanceTrace);
            
            if any(mappedConductanceTrace > 10)
                mappedConductanceTrace = zeros(1,length(mappedConductanceTrace)); %#ok<PREALL>
                error(['G_',conductance, ': voltage command out of range!'])
            end
            
            gen.waveshape = mappedConductanceTrace;
            stim = gen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            excConductance = obj.determineConductance();
            
            epoch.addStimulus(obj.rig.getDevice('Excitatory conductance'), ...
                obj.createConductanceStimulus('exc', excConductance));
            epoch.addStimulus(obj.rig.getDevice('Inhibitory conductance'), ...
                obj.createConductanceStimulus('inh', zeros(size(excConductance))));
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            epoch.addResponse(obj.rig.getDevice('Injected current'));
            
            epoch.addParameter('excitatoryConductance', excConductance);
        end
        
        function conductance = determineConductance(obj)
            conductance = obj.conductanceData.conductances(obj.epochToUse, :);
        end
        
        function volts = nSToVolts(obj, nS)
           volts = nS / obj.nSPerV; 
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            
            device = obj.rig.getDevice(obj.amp);
            interval.addDirectCurrentStimulus(device, device.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end
end