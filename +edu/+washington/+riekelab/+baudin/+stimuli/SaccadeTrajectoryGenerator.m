% Generates a sum of sine waves stimulus.

% Written using the framework of the built in Symphony 2.0 Sine Generator

classdef SaccadeTrajectoryGenerator < symphonyui.core.StimulusGenerator
    
    properties
        preTime                 % Leading duration (ms)
        tailTime                % Trailing duration (ms)
        
        trajectoryMaxContrast   % contrast of highest point on trajectory
        
        % these three vectors will come from the loaded file
        fixationTimes        % vector of times (ms)
        fixationDurations   % vector of durations (ms)
        amplitudes          % relative amplitudes of different fixations
        
        baseline            % baseline amplitude (units)
        sampleRate          % sample rate of generated stimulus (Hz)
        units               % units of generated stimulus
        
    end
    
    methods
        
        function obj = SaccadeTrajectoryGenerator(map)
            if nargin < 1
                map = containers.Map();
            end
            obj@symphonyui.core.StimulusGenerator(map);
        end  
    end
    
    methods (Access = protected)
        
        function s = generateStimulus(obj)
            
            import Symphony.Core.*;
 
            prePts = obj.TimeToPts(obj.preTime);
            stimPts = obj.CalculateStimPts();
            tailPts = obj.TimeToPts(obj.tailTime);

            stim = ones(1, prePts + stimPts + tailPts) * obj.baseline;
            
            fixationPts = TimeToPts(obj.fixationTimes);
            durationPts = TimeToPts(obj.fixationDurations);
            
            trajectory = zeros(1, stimPts);
            numFixations = numel(obj.saccadeTimes);
            endOfLast = 0;
            ampOfLast = 0;
            for i = 1:numFixations
                % start with ramp
                rampSlope = (obj.amplitudes(i) - ampOfLast) / ...
                    (fixationPts(i) - endOfLast);
                stim(endOfLast + 1:fixationPts(i)) = ...
                    (1:(fixationPts(i) - endOfLast - 1)) * rampSlope;
                stim(fixationPts(i):fixationPts(i) + durationPts(i)) = ...
                    obj.amplitudes(i);
                
                endOfLast = fixationPts(i);
                ampOfLast = obj.amplitudes(i);
            end
            
            stim(prePts + 1:prePts + stimPts) = ...
                obj.baseline + trajectory;
            
            parameters = obj.dictionaryFromMap(obj.propertyMap);
            measurements = Measurement.FromArray(stim, obj.units);
            rate = Measurement(obj.sampleRate, 'Hz');
            output = OutputData(measurements, rate);
            
            cobj = RenderedStimulus(class(obj), parameters, output);
            s = symphonyui.core.Stimulus(cobj);
        end
        
        function pts = TimeToPts(obj, tm)
            pts = round(obj.sampleRate * tm / 1000);
        end
        
        % stim pts will come from the last fixation time + its duration
        function pts = CalculateStimPts(obj)
            pts = obj.TimeToPts(obj.fixationTimes(end)) + ...
                obj.TimeToPts(obj.fixationDurations(end));
        end
    end
end
