% Generates a sum of sine waves stimulus.

% Written using the framework of the built in Symphony 2.0 Sine Generator

classdef SumSinesGenerator < symphonyui.core.StimulusGenerator
    
    properties
        preTime     % Leading duration (ms)
        stimTime    % Sine wave duration (ms)
        tailTime    % Trailing duration (ms)
        
        frequencies % frequencies of sines to sum
        contrasts   % contrasts of sines to sum
        phases      % phase offsets of each sine

        mean        % Mean amplitude (units)
        sampleRate  % Sample rate of generated stimulus (Hz)
        units       % Units of generated stimulus
        
    end
    
    methods
        
        function obj = SumSinesGenerator(map)
            if nargin < 1
                map = containers.Map();
            end
            obj@symphonyui.core.StimulusGenerator(map);
            
            % if the user forgot to specify a phase, or didn't specify
            % enough, make the phase offsets all zero
            if numel(obj.phases) ~= numel(obj.frequencies)
                obj.phases = zeros(size(obj.frequencies));
            end
            
        end  
    end
    
    methods (Access = protected)
        
        function s = generateStimulus(obj)
            
            import Symphony.Core.*;
            
            timeToPts = @(t)(round(t / 1e3 * obj.sampleRate));
            
            prePts = timeToPts(obj.preTime);
            stimPts = timeToPts(obj.stimTime);
            tailPts = timeToPts(obj.tailTime);
            
            data = ones(1, prePts + stimPts + tailPts) * obj.mean;
            
            time = (1:stimPts) / obj.sampleRate;
            
            for i = 1:numel(obj.frequencies)
                contr = obj.mean * obj.contrasts(i);
                data(prePts + 1:prePts + stimPts) = ...
                    data(prePts + 1:prePts + stimPts) + ...
                    createSinusoid( ...
                    contr, obj.frequencies(i), ...
                    obj.phases(i), ...
                    time);
            end
            
            parameters = obj.dictionaryFromMap(obj.propertyMap);
            measurements = Measurement.FromArray(data, obj.units);
            rate = Measurement(obj.sampleRate, 'Hz');
            output = OutputData(measurements, rate);
            
            cobj = RenderedStimulus(class(obj), parameters, output);
            s = symphonyui.core.Stimulus(cobj);
            
            function vec = createSinusoid(amp, freq, phase, time)
                vec = amp * sin(2 * pi * freq * time + phase);
            end
        end
    end
end
