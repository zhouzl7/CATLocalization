run('Parameters');
offset_frequency = 100;
clip_length = sampling_frequency * clip_time;
blank_length_left = sampling_frequency * blank_time_left;
blank_length_right = sampling_frequency * blank_time_right;
total_time = clip_time + blank_time_right;
total_length = clip_length + blank_length_right;
sampling_point = 0: 1 / sampling_frequency: clip_time - 1 / sampling_frequency;

%% find valid interval
[data_signal, ~] = audioread('.\sound\received.wav');
data_signal = data_signal(:, 1)';

single_chirp_1 = chirp(sampling_point, begin_frequency_1, clip_time, end_frequency_1, 'linear');
single_chirp_2 = chirp(sampling_point, begin_frequency_2, clip_time, end_frequency_2, 'linear');

[correlation, lag] = xcorr(data_signal, single_chirp_1);
pos = (length(lag) + 1) / 2;
correlation = correlation(pos: end);
lag = lag(pos: end);
[max_corr, index] = max(correlation);
for i = 1: length(correlation)
    if(correlation(i) > max_corr / 10)
        index = i;
        break;
    end
end
start = lag(index) + 1 - shift;

[correlation, lag] = xcorr(data_signal, single_chirp_2);
pos = (length(lag) + 1) / 2;
correlation = correlation(pos: end);
lag = lag(pos: end);
[max_corr, index] = max(correlation);
for i = length(correlation): -1: 1
    if(correlation(i) > max_corr / 10)
        index = i;
        break;
    end
end
finish = min(length(data_signal), lag(index) + clip_length + blank_length_left - blank_length_right);
data_signal = data_signal(start: finish);
clip_count = round(length(data_signal) / total_length);
actual_length = clip_count * total_length;
if(length(data_signal) > actual_length)
    data_signal = data_signal(1: actual_length);
else
    data_signal(end + 1: actual_length) = 0;
end

d1 = A / 2;
d2 = A / 2;
f1 = abs(begin_frequency_1 - end_frequency_1) * d1 / wave_speed / clip_time;
f2 = abs(begin_frequency_2 - end_frequency_2) * d2 / wave_speed / clip_time;

%% analyze x coordination
doppler_result = zeros(1, clip_count);
indexes_1 = zeros(1, clip_count);
for i = 1: total_length: 1 + total_length * (clip_count - 1)
    piece = data_signal(i: i + clip_length - 1);
    f = abs(fft(piece, fft_length));
    scale_begin = round((doppler_frequency - offset_frequency) * fft_length / sampling_frequency);
    scale_end = round((doppler_frequency + offset_frequency) * fft_length / sampling_frequency);
    [~, id] = max(f(scale_begin: scale_end)); 
    doppler_result(round((i - 1) / total_length) + 1) = (id + scale_begin - 1) * sampling_frequency / fft_length;
    piece = BPassFilter(piece, begin_frequency_1 - offset_frequency, end_frequency_1 + offset_frequency, sampling_frequency);
    s = piece .* single_chirp_1;
    spectrum = abs(fft(s, fft_length));
    [~, index] = max(abs(spectrum(1: round(fft_length / 10))));
    indexes_1(round((i - 1) / total_length) + 1) = index - 1;
end
distance_1 = indexes_1 * sampling_frequency / fft_length * wave_speed * clip_time / abs(end_frequency_1 - begin_frequency_1);
for i = 2: length(distance_1)
    speed = (distance_1(i) - distance_1(i - 1)) / total_time;
    if(speed > 1.5)
        distance_1(i) = distance_1(i - 1);
    end
end

%% analyze y coordination
indexes_2 = zeros(1, clip_count);
for i = 1 + blank_length_left: total_length: 1 + blank_length_left + total_length * (clip_count - 1)
    piece = data_signal(i: i + clip_length - 1);
    piece = BPassFilter(piece, begin_frequency_2 - offset_frequency, end_frequency_2 + offset_frequency, sampling_frequency);
    s = piece .* single_chirp_2;
    spectrum = abs(fft(s, fft_length));
    [~, index] = max(abs(spectrum(1: round(fft_length / 10))));
    indexes_2(round((i - 1 - blank_length_left) / total_length) + 1) = index - 1;
end
distance_2 = indexes_2 * sampling_frequency / fft_length * wave_speed * clip_time / abs(end_frequency_2 - begin_frequency_2);
for i = 2: length(distance_2)
    speed = (distance_2(i) - distance_2(i - 1)) / total_time;
    if(speed > 1.5)
        distance_2(i) = distance_2(i - 1);
    end
end
figure;
subplot(3, 1, 1);
plot((0: (clip_count - 1)) * total_time, doppler_result);
xlabel('t');
ylabel('doppler shift');
subplot(3, 1, 2);
distance_1 = distance_1 - distance_1(1) + d1;
distance_2 = distance_2 - distance_2(1) + d2;
plot((0: (clip_count - 1)) * total_time, distance_1);
xlabel('t');
ylabel('measured distance 1');
subplot(3, 1, 3);
plot((0: (clip_count - 1)) * total_time, distance_2);
xlabel('t');
ylabel('measured distance 2');
figure;
x_position = (distance_2 .^ 2  - distance_1 .^ 2 + A ^ 2) / 2 / A;
y_position = sqrt(max(0, distance_2 .^ 2 - x_position .^ 2)); 
for i = 2: length(x_position)
    speed = abs(x_position(i) - x_position(i - 1)) / total_time;
    if(speed > 2)
        x_position(i) = x_position(i - 1);
    end
end
for i = 2: length(x_position)
    speed = abs(y_position(i) - y_position(i - 1)) / total_time;
    if(speed > 2)
        y_position(i) = y_position(i - 1);
    end
end
subplot(2, 1, 1);
plot((0: clip_count - 1) * total_time, x_position);
xlabel('t');
ylabel('position x');
subplot(2, 1, 2);
plot((0: clip_count - 1) * total_time, y_position);
xlabel('t');
ylabel('position y');

real_trackX = [];
real_trackY = [];
figure;
plot(0, 0, 'bo', 0.4, 0, 'bo', real_trackX, real_trackY, 'b', x_position, y_position, 'r*-');