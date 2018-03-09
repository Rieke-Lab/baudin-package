classdef OnlineLinearFilter < handle
    properties
        sampleRate
        offsetForCutoffFrequency
        currentMeanResponseFft
        currentMeanStimulusFft
        numberOfEpochsCompleted
    end
    
    methods
        function obj = OnlineLinearFilter(responsePoints, sampleRate, cutoffFrequency)
            obj.sampleRate = sampleRate;
            
            if cutoffFrequency < sampleRate / 2
                obj.offsetForCutoffFrequency = ceil(cutoffFrequency * responsePoints / sampleRate);
            else
                obj.offsetForCutoffFrequency = (responsePoints / 2) - 1;
            end

            obj.numberOfEpochsCompleted = 0;
            obj.currentMeanResponseFft = zeros(1, responsePoints);
            obj.currentMeanStimulusFft = zeros(1, responsePoints);
        end
        
        function AddEpochData(obj, stimulus, response)
            % update stimulus fft
            stimulusFft = fft(stimulus);
            obj.currentMeanStimulusFft = ...
                (obj.numberOfEpochsCompleted / (obj.numberOfEpochsCompleted + 1)) * obj.currentMeanStimulusFft ...
                + (1 / (obj.numberOfEpochsCompleted + 1)) * stimulusFft;
            
            % update response fft
            responseFft = fft(response);
            obj.currentMeanResponseFft = ...
                (obj.numberOfEpochsCompleted / (obj.numberOfEpochsCompleted + 1)) * obj.currentMeanResponseFft ...
                + (1 / (obj.numberOfEpochsCompleted + 1)) * responseFft;
            
            % increment completed epochs counter
            obj.numberOfEpochsCompleted = obj.numberOfEpochsCompleted + 1;
        end
        
        function linearFilter = ComputeCurrentLinearFilter(obj)
            linearFilterFft = (obj.currentMeanResponseFft .* conj(obj.currentMeanStimulusFft)) ...
                ./ (obj.currentMeanStimulusFft .* conj(obj.currentMeanStimulusFft));
            
            % remove frequencies beyond cutoff frequency
            linearFilterFft(1 + obj.offsetForCutoffFrequency:end - obj.offsetForCutoffFrequency) = 0;
            
            linearFilter = real(ifft(linearFilterFft));
        end
        
        function linearFilter = AddEpochDataAndComputeCurrentLinearFilter(obj, stimulus, response)
            obj.AddEpochData(stimulus, response);
            linearFilter = obj.ComputeCurrentLinearFilter();
        end
    end
    
end