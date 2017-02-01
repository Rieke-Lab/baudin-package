function linearFilter = getLinearFilterOnlineWithoutNorm(stimulus, response, sampleRate, freqCutoff)

% this function will find the linear filter that changes row vector "signal" 
% into a set of "responses" in rows.  "samplerate" and "freqcuttoff" 
% (which should be the highest frequency in the signal) should be in HZ.

filterFft = mean((fft(response, [], 2) .* conj(fft(stimulus, [], 2))), 1);

cutoffPts = round(freqCutoff / (sampleRate / length(stimulus))) ; % this adjusts the freq cutoff for the length
filterFft(:, 1 + cutoffPts:length(stimulus) - cutoffPts) = 0 ; 

linearFilter = real(ifft(filterFft)) ;

end