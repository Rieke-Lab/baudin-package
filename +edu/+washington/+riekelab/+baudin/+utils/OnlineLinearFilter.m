classdef OnlineLinearFilter < handle
    properties
        sampleRate
        offsetForCutoffFrequency
        currentFilterFft
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
            obj.currentFilterFft = zeros(1, responsePoints);
        end
        
        function AddEpochData(obj, stimulus, response)
            % calculate stimulus fft
            stimulusFft = fft(stimulus);
            
            % calculate response fft 
            responseFft = fft(response);
            
            % calculate the filter fft
            filterFft = (responseFft .* conj(stimulusFft)) ./ (stimulusFft .* conj(stimulusFft));
            
            % set frequencies out of range to zero
            filterFft(1 + obj.offsetForCutoffFrequency:end - obj.offsetForCutoffFrequency) = 0;
            
            % update the running mean            
            obj.currentFilterFft = ...
                (obj.numberOfEpochsCompleted / (obj.numberOfEpochsCompleted + 1)) * obj.currentFilterFft ...
                + (1 / (obj.numberOfEpochsCompleted + 1)) * filterFft;
            
            % increment completed epochs counter
            obj.numberOfEpochsCompleted = obj.numberOfEpochsCompleted + 1;
        end
        
        function linearFilter = ComputeCurrentLinearFilter(obj)
            linearFilter = real(ifft(obj.currentFilterFft));
        end
        
        function linearFilter = AddEpochDataAndComputeCurrentLinearFilter(obj, stimulus, response)
            obj.AddEpochData(stimulus, response);
            linearFilter = obj.ComputeCurrentLinearFilter();
        end
    end
    
end