clc
close all
clear all
R = 20; % Bit stream 
S = 21; % Bit sequence length
bit_stream = round(rand(1,R)); % Random bit stream
PAM = zeros(1,S*R); % Predetermining PAM baseband signal

%% PAM signal generation using the Polar Non-Return-to-Zero 

signal
for i = 1:R
    if bit_stream(1,i) == 0
        PAM(1+(i-1)*S : i*S) = -1;
    else
        PAM(1+(i-1)*S : i*S) =  1;
    end
end
subplot(3,2,1)
plot(PAM);
axis([-1 S*R+10 -1.2 1.2]);
title('Original PAM base signal generated using non-zero polar alarm');

%% Fourier transform

z = abs(fft(xcorr(PAM)));
subplot(3,2,2);
plot(z);
axis([0 840 0 1.1*max(z)]);
title('PSD of the PAM signal');

%% Creating a pseudo-random sequence for distribution

pn_seq = round(rand(1,60)); 
% Creating a pseudo-random SIGNAL for distribution
t = 0:2*pi/6:2*pi; % Create 7 samples for one cosine
c = sin(t);
carrier = [];
pn_sig_txr1 = zeros(1,S*R); % Pseudo noise signal in trx.
for i = 1:60
    if pn_seq(1,i) == 0
        pn_sig_trx1(1+(i-1)*7:i*7) = -1;
    else
        pn_sig_trx1(1+(i-1)*7:i*7) =  1;
    end  
    carrier = [carrier c];
end
K = round(rand(1,1)*420);
pn_sig_trx = [pn_sig_trx1(K:end) pn_sig_trx1(1:K-1)];
% Sequence spread
spreaded_sig = PAM .* pn_sig_trx;
subplot(3,2,3);
plot(spreaded_sig);
axis([-1 S*R+10 -1.2 1.2]);
title('Sequence spread');
z = abs(fft(xcorr(spreaded_sig))); % PSD of the spreaded signal
subplot(3,2,4);
plot(z);
axis([0 840 0 1.1*max(z)]);
title('PSD of the spreaded signal');

%% BPSK modulated spreaded signal

bpsk_sig = spreaded_sig .* carrier; % Signal modulation
subplot(3,2,5);
plot(bpsk_sig)
axis([-1 100 -1.2 1.2]); 
title('BPSK modulated signal (first 100 samples)');

%% Building a PSD signal with a pseudo-random sequence DSSS signal.

y = abs(fft(xcorr(bpsk_sig)));
subplot(3,2,6)
plot(y)
xlabel('Frequency(Hz)')
ylabel('Power')
title('Power spectral density (W / Hz)')

%% Demodulation and compression of the received signal.

integrand = bpsk_sig .* carrier;   % Signal integration
demod_sig = zeros(1,S*R);           % Signal demodulation
for i = 1:60
    if sum(integrand(1+(i-1)*7 : 7*i))>=0
        demod_sig(1+(i-1)*7 : 7*i) = 1;
    else
        demod_sig(1+(i-1)*7 : 7*i) = -1;
    end
end

%% Addition of the demodulated signal taking into account time
synchronization using parallel search

P = zeros(1,60);    
disp('Parallel Search strategy started...')
b_r = zeros(60,R); % Recovered bitstream corresponding to each signal
BER = zeros(1,60); % Error bit rate
for i = 1:60
    
    % Creating various delayed versions of the PN signal in the receiver

    pn_sig_rcx = [pn_sig_trx1(7*(i-1)+3:end) pn_sig_trx1(1:7*(i-1)+2)];
    
    % Signal compression
    hyp_sig = demod_sig .* pn_sig_rcx;      
    b_r(i,:) = hyp_sig(1:S:end);
    BER(i) = sum(abs(bit_stream - b_r(i,:)))/R;
    
    % Delay calculation
    z = abs(fft(xcorr(hyp_sig)));
    
    % Acquiring signal power
    P(i) = sum(z(1:30));    
    
    % Results display
    if mod(i-1,12) == 0
        figure
        subplot(2,1,1)
        plot(hyp_sig)
        % titel('Compressed signal')
        axis([-1 S*R+10 -1.2 1.2]);
        % title(['Compressed data using delay values']);
        
        % Power Spectrum
        subplot(2,1,2)
        plot(z)
        axis([0 840 0 1.1*max(z)])
        xlabel('Frequency(Hz)')
        ylabel('Power')
        title('Power spectral density')
    end
end
D = find(P == max(P)); % The real delay of the PN signal in the receiver
s = demod_sig .* [pn_sig_trx1(7*(D-1)+3:end) pn_sig_trx1(1:7*(D-1)+2)];                                   
ss = abs(fft(xcorr(s))); % PSD of the maximum low-frequency energy signal
figure
subplot(2,1,1);
plot(s);
axis([-1 S*R+10 -1.2 1.2]);
title('Maximum low energy signal');
subplot(2,1,2);
plot(ss)
axis([0 840 0 1.1*max(ss)])
xlabel('Frequency(Hz)')
ylabel('Power')
title('Power spectral density')
figure;
% Colormap summer
bar(BER)
colormap(summer)
stem(BER,'MarkerFaceColor','red','Marker','square');
axis([0 61 0.5*min(BER) 1.2*max(BER)]);
title('Bit Error Reate for different delay values.')

%% Building a BER

 num_bit=1e5; %Signal length 
 max_run=20; %Maximum number of iterations for a single SNR
 Eb=1; %Bit energy
 SNRdB=0:1:10; %Signal to Noise Ratio (in dB)
 SNR=10.^(SNRdB/10);                      
 hand=waitbar(0,'Please Wait....');
 for count=1:length(SNR) %Beginning of loop for different SNR
     avgError=0;
     No=Eb/SNR(count); %Calculate noise power from SNR
     for run_time=1:max_run %Beginning of loop for different runs
         waitbar((((count-1)*max_run)+run_time-1)/(length(SNRdB)*max_run));
         Error = 0;
         data = randn(1,num_bit); %Generate binary data source
         s = 2*data-1; %Baseband BPSK modulation
         N = sqrt(No/2)*randn(1,num_bit); %Generate AWGN
         Y = s+N; %Received Signal
         for k=1:num_bit %Decision device taking hard decision and deciding error
             if ((Y(k)>0 && data(k)==0)||(Y(k)<0 && data(k)==1))
                 Error=Error+1;
             end
         end
         Error=Error/num_bit; %Calculate error/bit
         avgError=avgError+Error; %Calculate error/bit for different runs        
     end  %Termination of loop for different runs
     BER_sim(count)=avgError/max_run; %Calculate BER for a particular SNR                                  
 end   %Termination of loop for different SNR 
 BER_th=(1/2)*erfc(sqrt(SNR)); %Calculate analytical BER
 close(hand);
 semilogy(SNRdB,BER_th,'r'); %Plot BER
 hold on
 semilogy(SNRdB,BER_sim,'b*');
 legend('Theoretical','Simulation');
 axis([min(SNRdB) max(SNRdB) 10^(-7) 1]);
 hold off
