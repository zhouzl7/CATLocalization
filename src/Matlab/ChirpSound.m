%% generate transmit signal
run('Parameters');
clip_length = sampling_frequency * clip_time;
sampling_point = 0: 1 / sampling_frequency: clip_time - 1 / sampling_frequency;
doppler_signal = cos(2 * pi * doppler_frequency * sampling_point);
single_chirp_1 = chirp(sampling_point, begin_frequency_1, clip_time, end_frequency_1, 'linear') + doppler_signal;
single_chirp_1 = single_chirp_1 / max(abs(single_chirp_1));
clip_1 = [single_chirp_1, zeros(1, sampling_frequency * blank_time_right)];
single_chirp_2 = chirp(sampling_point, begin_frequency_2, clip_time, end_frequency_2, 'linear');
clip_2 = [zeros(1, sampling_frequency * blank_time_left), single_chirp_2, zeros(1, sampling_frequency * blank_time_right - sampling_frequency * blank_time_left)];
output_1 = repmat(clip_1, 1, clip_count);
output_2 = repmat(clip_2, 1, clip_count);
data = [output_1; output_2]';
% generate sound
audiowrite('.\sound\output.wav', data, sampling_frequency, 'BitsPerSample', 16);
sound(data, sampling_frequency);