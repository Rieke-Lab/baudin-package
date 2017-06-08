classdef DynamicClampRepeatedSeedNoise < edu.washington.riekelab.protocols.RiekeLabProtocol
    properties
        gExcMultiplier = 1
        gInhMultiplier = 1
        conductances = 'foveal midget';
        ExcReversal = 10;
        InhReversal = -70;
        
        nSPerVolt = 20;
        
        epochsToRepeat = [1, 2];
        
        amp
        %         numberOfAverages = uint16(5)
        interpulseInterval = 0.2
    end
    
    properties (Constant)
        CONDUCTANCE_FILENAMES = containers.Map( ...
            {'foveal midget', 'peripheral midget', 'peripheral parasol'}, ...
            {'foveal_midget_conductances.mat', ...
            'peripheral_midget_conductances.mat', ...
            'peripheral_parasol_conductances.mat'})
    end
    
    properties (Hidden)
        ampType
        conductancesType = symphonyui.core.PropertyType('char', 'row', ...
            edu.washington.riekelab.baudin.protocols.DynamicClampRepeatedSeedNoise.CONDUCTANCE_PATH_LOOKUP.keys());
        conductanceData
        numEpochs
    end
    
    methods
        function loadConductanceData(obj)
            filename = obj.CONDUCTANCE_FILENAMES(obj.conductance);
            resourcesFolder = what(fullfile('edu', 'washington', 'riekelab', 'baudin', 'resources'));
            obj.conductanceData = fullfile(resourcesFolder.path, filename);
        end
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            % load the conductances
            obj.loadConductanceData();
            obj.numEpochs = size(obj.conductanceData.conductances, 1) * (1 + numel(obj.epochsToRepeat));
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.turner.figures.DynamicClampFigure',...
                obj.rig.getDevice(obj.amp), obj.rig.getDevice('Excitatory conductance'),...
                obj.rig.getDevice('Inhibitory conductance'), obj.rig.getDevice('Injected current'),...
                obj.ExcReversal, obj.InhReversal);
            obj.showFigure('edu.washington.riekelab.figures.ProgressFigure', obj.numEpochs)
            
            %set the backgrounds on the conductance commands
            %0.05 V command per 1 nS conductance
            c = obj.conductanceData;
            allPrePts = c.conductances(:, 1:(c.preTime * c.sampleRate / 1e3));
            excBackground = obj.nSToVolts(obj.gExcMultiplier * mean(allPrePts(:)));
            obj.rig.getDevice('Excitatory conductance').background = symphonyui.core.Measurement(excBackground, 'V');
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
            % often, 200 nS = 10 V, 1 nS = 0.05 V
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
            
            [excConductance, excConductanceIdx] = obj.determineConductance(obj.numEpochsPrepared);
            
            epoch.addStimulus(obj.rig.getDevice('Excitatory conductance'), ...
                obj.createConductanceStimulus('exc', excConductance));
            epoch.addStimulus(obj.rig.getDevice('Inhibitory conductance'), ...
                obj.createConductanceStimulus('inh', zeros(size(excConductance))));
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            epoch.addResponse(obj.rig.getDevice('Injected current'));
            
            %             epoch.addParameter('excitatoryConductance', excConductance);
            epoch.addParameter('excitatoryConductanceIdx', excConductanceIdx);
            epoch.addParameter('preTime', obj.conductanceData.preTime);
            epoch.addParameter('stimTime', obj.conductanceData.stimTime);
            epoch.addParameter('tailTime', obj.conductanceData.tailTime);
            epoch.addParameter('dataID', obj.conductanceData.dataID);
        end
        
        function [conductance, idx] = determineConductance(obj, epochNum)
            numCycles = numel(obj.epochsToRepeat) + 1;
            if mod(epochNum, numCycles) == 1
                idx = floor(epochNum / (numCycles)) + 1;
            else
                idx = obj.epochsToRepeat(mod(epochNum - 1, numCycles));
            end
            conductance = obj.conductanceData.conductances(idx, :);
        end
        
        function volts = nSToVolts(obj, nS)
            volts = nS / obj.nSPerVolt;
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            
            device = obj.rig.getDevice(obj.amp);
            interval.addDirectCurrentStimulus(device, device.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numEpochs;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numEpochs;
        end
    end
end