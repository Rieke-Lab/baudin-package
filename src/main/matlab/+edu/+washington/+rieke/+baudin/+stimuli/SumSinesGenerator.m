% Generates a sum of sine waves stimulus.

% Written using the framework of the built in Symphony 2.0 Sine Generator

classdef SumSinesGenerator < symphonyui.core.StimulusGenerator
    
    properties
        preTime     % Leading duration (ms)
        stimTime    % Sine wave duration (ms)
        tailTime    % Trailing duration (ms)
        amplitude   % Vector of sine wave amplitudes (units)
        period      % Vector of sine wave periods (ms)
        phase       % Vector of sine wave phase offsets (radians)
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
            if numel(obj.phase) ~= numel(obj.amplitude)
                obj.phase = zeros(size(obj.amplitude));
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
            
            for i = 1:numel(obj.amplitude)
                data(prePts + 1:prePts + stimPts) = ...
                    data(prePts + 1:prePts + stimPts) + ...
                    createSinusoid(obj.period(i));
            end
            
            parameters = obj.dictionaryFromMap(obj.propertyMap);
            measurements = Measurement.FromArray(data, obj.units);
            rate = Measurement(obj.sampleRate, 'Hz');
            output = OutputData(measurements, rate);
            
            cobj = RenderedStimulus(class(obj), parameters, output);
            s = symphonyui.core.Stimulus(cobj);
            
            function vec = createSinusoid(per)
                freq = 2 * pi / (per * 1e-3);
                time = (0:stimPts-1) / obj.sampleRate;
                vec = obj.mean + obj.amplitude * sin(freq * time + obj.phase);
            end
        end
        
    end
    
end
