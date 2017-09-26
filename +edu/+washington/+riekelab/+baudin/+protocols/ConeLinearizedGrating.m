classdef ConeLinearizedGrating < edu.washington.riekelab.protocols.RiekeLabStageProtocol

    properties
        stimulusDataPath = 'enter path here'; % string of path to
        isomerizationsAtMonitorValue1 = 0;
        inputStimulusFrameRate = 60;
        preFrames = 30
        postFrames = 30
        rotation = 0; % degrees
        maskDiameter = 0; % um
        onlineAnalysis = 'none';
        averagesPerStimulus = uint16(20);

        onlineAnalysis = 'none'
        numberOfAverages = uint16(20) % number of epochs to queue
        amp
    end

    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        stimuli
        currentStimuli
        stimulusDurationSeconds
        backgroundIsomerizations
    end

    properties (Hidden, Transient)
        analysisFigure
    end

    methods

        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        function constructStimuli(obj)
            obj.stimuli = struct;
            obj.stimuli.names = {'positive corrected', ...
            'negative corrected', ...
            'both corrected', ...
          'positive uncorrected', 'negative uncorrected', 'both uncorrected'}

          stimulusData = load(obj.stimulusDataPath);
          obj.backgroundIsomerizations = stimulusData.positiveCorrected(1)
          meanVector = obj.backgroundIsomerizations ...
          * ones(1, numel(stimulusData.positiveCorrected));

          obj.stimuli.lookup = containers.Map(obj.stimuli.names, ...
          {{stimulusData.positiveCorrected, meanVector}, ...
          {meanVector, stimulusData.negativeCorrected}, ...
          {stimulusData.positiveCorrected, stimulusData.negativeCorrected}, ...
          {stimulusData.positiveUncorrected, meanVector}, ...
          {meanVector, stimulusData.negativeUncorrected}, ...
          {stimulusData.positiveUncorrected, stimulusData.negativeUncorrected}});

          obj.stimulusDurationSeconds = (obj.preFrames + numel(stimulusData.positiveCorrected(1)) + obj.postFrames) ...
          / obj.inputStimulusFrameRate;
        end

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

            if length(obj.barWidth) > 1
                colors = edu.washington.riekelab.turner.utils.pmkmp(length(obj.barWidth),'CubicYF');
            else
                colors = [0 0 0];
            end

            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.turner.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'groupBy',{'currentBarWidth'},...
                'sweepColor',colors);
            obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
        end

        function intensityController = createIntensityController(obj, rectangle, stimulus)
          paddedStimulus = [obj.backgroundIsomerizations * ones(1, obj.preFrames) ...
          stimulus ...
          obj.backgroundIsomerizations * ones(1, obj.postFrames)];
          intensityController = stage.builtin.controllers.PropertyController( ...
          rectangle, ...
        'color', ...
      @(state) paddedStimulus(state.frame));
        end

        function color = isomerizationsToColor(obj, isomerizations)
            color = (isomerizations / obj.isomerizationsAtMonitorValue1) * ones(1, 3);
        end

        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();

            leftStimulus = obj.getLeftStimulus();
            rightStimulus = obj.getRightStimulus();

            p = stage.core.Presentation( ...
              obj.stimulusDurationSeconds); %create presentation of specified duration
            p.setBackgroundColor(obj.isomerizationsToColor(obj.backgroundIsomerizations)); % Set background intensity

            leftRectangle = stage.builtin.stimuli.Rectangle()
            leftRectangle.size = canvasSize .* [0.25 1];
            leftRectangle.color = obj.isomerizationsToColor(obj.backgroundIsomerizations);
            p.addStimulus(leftRectangle);
            p.addController(obj.createIntensityController(leftRectangle, leftStimulus));

            rightRectangle = stage.builtin.stimuli.Rectangle()
            rightRectangle.size = canvasSize .* [0.75 1];
            rightRectangle.color = obj.isomerizationsToColor(obj.backgroundIsomerizations);
            p.addStimulus(rightRectangle);
            p.addController(obj.createIntensityController(rightRectangle, rightStimulus));

            mask = stage.builtin.stimuli.Ellipse();
            maskDiameterPixels = obj.rig.getDevice('Stage').um2pix(obj.maskDiameter);
            mask.position = canvasSize / 2;
            mask.color = obj.isomerizationsToColor(obj.backgroundIsomerizations);
            mask.radiusX = maskDiameterPixels / 2;
            mask.radiusY = maskDiameterPixels / 2;
            p.addStimulus(mask); %add mask
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);

            index = mod(obj.numEpochsCompleted - 1, numel(obj.stimuli.names)) + 1;

            obj.currentStimuli = obj.stimuli.lookup(obj.stimuli.names{index});

            ampDevice = obj.rig.getDevice(obj.amp);
            duration = obj.stimulusDurationSeconds;
            epoch.addDirectCurrentStimulus(ampDevice, ampDevice.background, duration, obj.sampleRate);
            epoch.addResponse(ampDevice);

            epoch.addParameter('stimulus type', currentStimulusType);
            epoch.addParameter('left stimulus', obj.getLeftStimulus());
            epoch.addParameter('right stimulus', obj.getRightStimulus());
        end

        function stimulus = getLeftStimulus(obj)
          stimulus = obj.currentStimulus{1};
        end

        function stimulus = geRightStimulus(obj)
          stimulus = obj.currentStimulus{2};
        end

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages * numel(obj.stimuli.names);
        end

        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages * numel(obj.stimuli.names);
        end
    end
end
