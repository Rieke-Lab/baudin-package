classdef DynamicClampBaselineSpikeRate < edu.washington.riekelab.protocols.RiekeLabProtocol
    properties
        ExcReversal = 10;
        InhReversal = -70;
        
        epochTime
        
        nSPerV = 20;
        
        amp
        numberOfAverages = uint16(5)
        interpulseInterval = 0.2
    end
    
    properties (Hidden)
        spikeRateFigure
        spikeRateLine = [];
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
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
        end
        
        function intializeSpikeRateFigure(obj)
            obj.spikeRateLine = [];
            obj.spikeRateFigure.Color = 'w';
            axHand = obj.spikeRateFigure.userData.axesHandle;
            cla(axHand);
            axHand.XLabel.String = 'epoch number';
            axHand.YLabel.String = 'spike rate (Hz)';
            axHand.Title.String = 'baseline spike rate monitor';
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
               obj.spikeRateLine = plot(obj.spikeRateFigure.userData.axesHandle, ...
                   1, spikeRate, ...
                   'LineWidth', 2, ...
                   'Color', [0.2 0.2 1]);
               text(obj.spikeRateFigure.userData.axesHandle, ...
                   1, spikeRate * 1.1, ...
                   num2str(spikeRate));
            else
                epochNum = numel(obj.spikeRateLine.XData) + 1;
                set(obj.spikeRateLine, ...
                    {'XData', 'YData'}, ...
                    {(1:epochNum), [obj.spikeRateLine.YData spikeRate]});
                text(obj.spikeRateFigure.userData.axesHandle, ...
                   epochNum, spikeRate * 1.1, ...
                   num2str(spikeRate));
            end
        end
        
        function stim = createZeroConductanceStimulus(obj)
            gen = symphonyui.builtin.stimuli.WaveformGenerator();
            gen.sampleRate = obj.sampleRate;
            gen.units = 'V';
            gen.waveshape = zeros(1, obj.timeToPts(obj.epochTime)); 
            gen.waveshape = mappedConductanceTrace;
            stim = gen.generate();
        end
        
        function pts = timeToPts(obj, time)
           pts = time * obj.sampleRate / 1e3; 
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            epoch.addStimulus(obj.rig.getDevice('Excitatory conductance'), ...
                obj.createZeroConductanceStimulus(obj.epochTime));
            epoch.addStimulus(obj.rig.getDevice('Inhibitory conductance'), ...
                obj.createZeroConductanceStimulus(obj.epochTime));
            
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            epoch.addResponse(obj.rig.getDevice('Injected current'));
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