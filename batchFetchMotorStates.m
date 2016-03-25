function batchFetchMotorStates(filelist,region, datafilename, stimuliIndices)
%batchFetchMotorStates - A wrapper and output generator for getting information on active pixel fraction per location during the movie, after 'locationData' data structure has been returned and saved into 'region' from wholeBrain_activeFraction.m
%Examples:
% >> batchFetchMotorStates(filelist);
% >> batchFetchMotorStates({filename},region);
% >> batchFetchMotorStates(filelist,[],[], 'true', {'motor.state.active' 'motor.state.quiet'});
% >> batchFetchMotorStates({fnm},region,[], 'true', {'motor.state.active' 'motor.state.quiet' 'sleep'});
% >> batchFetchMotorStates({filename},region,'dMotorStates.txt', 'true', [2 3]);
%
%**USE**
%Must provide one input:
%
%(1) table with desired filenames (space delimited txt file, with full filenames in first column)
%files.txt should have matlab filenames in first column.
%can have an extra columns with descriptor/factor information for the file. This will be the rowinfo that is attached to each measure observation in the following script.
%filelist = readtext('files.txt',' '); %grab readtext.m file script from matlab central
%or
%(2) a single filename (filename of your region .mat file) as a cell array, i.e.  {filename}
%
%Options:
%filelist={filename}; % cell array of strings, can pass just a single filename and a single already loaded region structure, if only getting values for a single file.
%region - datastructure, if you just want to do a single file loaded into workspace
%datafilename - string, append data to prexisting table with filename 'datafilename'
%stimuliIndices - integer vector of stimulus indices or a cell array of strings of stimulus descriptions for selecting stimuli in your region.stimuli data structure
%
%Output:
%Right now this function will automatically write to a space-delimited txt file outputs, a 'region.location/active period type' based dataset 'dLocationProps.txt'
%And these outputs will be appended if the file already exists.
%
% See also wholeBrain_motorSignal, mySpikeDetect, batchFetchStimResponseProps, batchFetchMotorStates, detectMotorStates, rateChannels, makeMotorStateStimParams, printStats
%
%James B. Ackman, 2016-03-24 15:24:50

%-----------------------------------------------------------------------------------------
%- Set up options and default parameters
%-----------------------------------------------------------------------------------------


if nargin< 4 || isempty(stimuliIndices); stimuliIndices = []; end 
if nargin< 3 || isempty(datafilename), 
	datafilename = 'dMotorStates.txt';
	matlabUserPath = userpath;  
	matlabUserPath = matlabUserPath(1:end-1);  
	datafilename = fullfile(matlabUserPath,datafilename);
else
	[pathstr, name, ext] = fileparts(datafilename);   %test whether a fullfile path was specified	
	if isempty(pathstr)  %if one was not specified, save the output datafilename into the users matlab home startup directory
		matlabUserPath = userpath;  
		matlabUserPath = matlabUserPath(1:end-1);  
		datafilename = fullfile(matlabUserPath,datafilename);		
	end
end
if nargin< 2 || isempty(region); region = []; end

%---**functionHandles.workers and functionHandles.main must be valid functions in this program or in matlabpath to provide an array of function_handles
functionHandles.workers = {@filename @matlab_filename @motorTimeFraction @motorFreq_hz @stimulusDesc @stimOn @stimOff @TimeFractionState @TimeState_sec @freqState_hz @area @ISI};
functionHandles.main = @wholeBrain_getMovementStats;
%tableHeaders = {'filename' 'matlab.filename' 'region.name' 'roi.number' 'nrois' 'roi.height.px' 'roi.width.px' 'xloca.px' 'yloca.px' 'xloca.norm' 'yloca.norm' 'freq.hz' 'intvls.s' 'onsets.s' 'durs.s' 'ampl.df'};
%filename %roi no. %region.name %roi size %normalized xloca %normalized yloca %region.stimuli{numStim}.description %normalized responseFreq %absolutefiringFreq(dFreq) %meanLatency %meanAmpl %meanDur


tableHeaders = cellfun(@func2str, functionHandles.workers, 'UniformOutput', false);
%---Generic opening function---------------------
setupHeaders = exist(datafilename,'file');
if setupHeaders < 1
	%write headers to file----
	fid = fopen(datafilename,'a');
	appendCellArray2file(datafilename,tableHeaders,fid)
else
	fid = fopen(datafilename,'a');
end

fetchMotorStates(filelist)

%---Generic main function loop-------------------
%Provide valid function handle
mainfcnLoop(filelist, region, datafilename, functionHandles, [], fid, stimuliIndices)
fclose(fid);





function fetchMotorStates(filelist,makePlots)
if nargin < 2 || isempty(makePlots), makePlots = 1; end
fnms = filelist(:,2);

for j=1:numel(fnms)
    load(fnms{j});  %load the dummy file at fnms{j} containing parcellations, motor signal, etc
    sprintf(fnms{j})    
    nframes = numel(region.motorSignal);

	[spks,~,~] = detectMotorOnsets(region, motorSignalGroupParams.nsd, motorSignalGroupParams.groupRawThresh, motorSignalGroupParams.groupDiffThresh, 0);
	region = makeStimParams(region, spks, 'motor.onsets', 1); 

	rateChan = rateChannels(region,[],0,[],motorSignalGroupParams.rateChanMaxlagsAll(motorSignalGroupParams.rateChanNum));

    x = rateChan(1).y;
    xbar = motorSignalGroupParams.rateChanMean;
    x(x<xbar) = 0;
    dfY = [diff(x) 0];

    ons = find(dfY > xbar); ons = ons+1;
    offs = find(dfY < -xbar);
    if ons(1) > offs(1)
        offs = offs(2:end);
    end

	% if no. of onsets not equal to offsets, try removing the first offset (in case detected in beginning of movie)
    if numel(ons) ~= numel(offs)
        offs = [offs numel(x)];
    end

    % if no. of onsets are still not equal to offsets, try the next smoothened rateChan trace
    if numel(ons) ~= numel(offs)
        error('Number of onsets not equal to number of offsets')
    end

    idx1=[];
    idx2=[];
    for i=1:length(ons)
        %disp(ons(i))
        tf = ismember(spks,ons(i):offs(i));
        ind = find(tf);
        if isempty(ind)
            idx1 = [idx1 ons(i)];
            idx2 = [idx2 offs(i)];
        else
            idx1 = [idx1 spks(ind(1))];
            if ind(end) ~= ind(1)
                idx2 = [idx2 spks(ind(end))];
            else
                %idx2 = [idx2 spks(ind(end))+1];  %add max([val length(trace)]) algorithm
                idx2 = [idx2 offs(i)];
            end
        end
    end

    region = makeMotorStateStimParams(region, idx1, idx2, 1);

    save(fnms{j},'region','-v7.3');  %load the dummy file at fnms{j} containing parcellations, motor signal, etc
end



function mainfcnLoop(filelist, region, datafilename, functionHandles, fid, stimuliIndices)
%start loop through files-----------------------------------------------------------------

if nargin < 6 || isempty(stimuliIndices), stimuliIndices=[]; end

if nargin< 2 || isempty(region); 
    region = []; loadfile = 1; 
else
    loadfile = 0;
end

fnms = filelist(:,2);  %assuming **second column** has your dummy files for this script...

for j=1:numel(fnms)
    if loadfile > 0
        load(fnms{j},'region');
    end
    
	[pathstr, name, ext] = fileparts(fnms{j});
	region.matfilename = [name ext];  %2012-02-07 jba    
	
    sprintf(fnms{j})    

    disp('--------------------------------------------------------------------')
	functionHandles.main(region, functionHandles.workers, datafilename, fid, stimuliIndices)
	if ismac | ispc
		h = waitbar(j/numel(fnms));
	else
		disp([num2str(j) '/' num2str(numel(fnms))])		
    end
end
%data=results;
if ismac | ispc
	close(h)
end









%-----------------------------------------------------------------------------------------
%dataFunctionHandle
function output = wholeBrain_getMovementStats(region, functionHandles, datafilename, fid, stimuliIndices)
%script to fetch the active and non-active pixel fraction period durations
%for all data and all locations
%2013-04-09 11:35:04 James B. Ackman
%Want this script to be flexible to fetch data for any number of location Markers as well as duration distributions for both non-active and active periods.  
%Should get an extra location signal too-- for combined locations/hemisphere periods.
%2013-04-11 18:00:23  Added under the batchFetchLocation generalized wrapper table functions

varin.datafilename=datafilename;
varin.region=region;

if isempty(stimuliIndices) & isfield(region,'stimuli'); 
	stimuliIndices=1:numel(region.stimuli);
elseif iscellstr(stimuliIndices) & isfield(region,'stimuli')  %if the input is a cellarray of strings
		ind = [];
		for i = 1:length(region.stimuli)
			for k = 1:length(stimuliIndices)
				if strcmp(region.stimuli{i}.description,stimuliIndices{k})
					ind = [ind i];
				end
			end
		end
		stimuliIndices = ind; %assign indices 
elseif isnumeric(stimuliIndices) & isfield(region,'stimuli')
	return
else
	error('Bad input to useStimuli, stimuliIndices, or region.stimuli missing')
end

%START loop here by stimulus.stimuliParams to make a stimulus period based dataset------------------------
for numStim = stimuliIndices
	for nstimuli=1:numel(region.stimuli{numStim}.stimulusParams)
		varin.numStim = numStim;
		varin.nstimuli = nstimuli;
		varin.stimulusdesc = region.stimuli{numStim}.description;
		varin.on = region.stimuli{numStim}.stimulusParams{nstimuli}.frame_indices(1);
		varin.off = region.stimuli{numStim}.stimulusParams{nstimuli}.frame_indices(end);
		printStats(functionHandles, varin, fid) 
	end
end
%END loop here by stimulus.stimuliParams-------------------------------



@filename @matlab_filename @motorTimeFractionAll @stimulusDesc @motorTimeFraction @motorFreq_hz @nstimuli @stimOn @stimOff @Duration_s @Area_uVs @ISI_s



function out = filename(varin) 
%movie .tif filename descriptor string
out = varin.region.filename;


function out = matlab_filename(varin)
%analysed .mat file descriptor string
out = varin.region.matfilename;


function out = motorTimeFractionAll(varin)
idx = find(varin.region.motorSignal >= varin.region.motorSignalGroupParams.groupRawThresh);
out = numel(idx)/varin.region.nframes;


function out = stimulusDesc(varin)
out = varin.stimulusdesc;


function out = motorTimeFraction(varin)
tf = false(1,varin.region.nframes);	
for i=1:numel(varin.region.stimuli{numStim}.stimulusParams)
	t1 = varin.region.stimuli{numStim}.stimulusParams{i}.frame_indices(1);
	t2 = varin.region.stimuli{numStim}.stimulusParams{i}.frame_indices(end);
	tf(t1:t2) = 1; 
end
tmpSignal = varin.region.motorSignal;
tmpSignal(~tf) = 0;
idx = find(tmpSignal >= varin.region.motorSignalGroupParams.groupRawThresh);
out = numel(idx)/varin.region.nframes;


function out = motorFreq_hz(varin)
out = numel(varin.region.stimuli{varin.numStim}.stimulusParams) / (varin.region.nframes*varin.region.timeres);


function out = nstimuli(varin)
out = varin.nstimuli;


function out = stimOn(varin) 
out = varin.on;


function out = stimOff(varin)
out = varin.off;

function out = Duration_s(varin)
out = (varin.off-varin.on+1).*varin.region.timeres;


function out = Area_uVs(varin)
out = numel(varin.region.stimuli{varin.numStim}.stimulusParams) / (varin.region.nframes*varin.region.timeres);

out = trapz(varin.on:varin.off*varin.region.timeres,vel);


function out = ISI_s(varin)
%wave ISI------------------------------------------------------------------
tmpres=region.timeres;
d=region.waveonsets;
e=region.waveoffsets;

d1 = [d size(region.traces,2)];
e1 = [0 e-d];
ints=diff([0 d1]) - e1;
if d(1) ~= 1
    ints=ints(2:end);
end
if d(end) ~= size(region.traces,2)
    ints=ints(1:end-1);
end
ints=ints*tmpres;















%------------Find active period functions---------------
function pulseSignal = makeActivePulseSignal(rawSignal)
pulseSignal = rawSignal;
pulseSignal(rawSignal>0) = 1;


function pulseSignal = makeNonActivePulseSignal(rawSignal)
pulseSignal = rawSignal;
pulseSignal(rawSignal>0) = -1;
pulseSignal(pulseSignal>-1) = 1;
pulseSignal(pulseSignal<1) = 0;


function [wvonsets, wvoffsets] = getPulseOnsetsOffsets(rawSignal,pulseSignal,plotTitles,locationName,makePlots)
if nargin < 5 || isempty(makePlots), makePlots = 0; end
if nargin < 4 || isempty(locationName), locationName = 'unknown location'; end
if nargin < 3 || isempty(plotTitles), plotTitles{1} = ['active fraction by frame for ' locationName]; plotTitles{2} = 'active periods to positive pulse'; plotTitles{3} = 'derivative of active pulse'; end

x = pulseSignal;
sig = rawSignal;
%ax = axesHandles;
dx = diff(x);
dx2 = [dx 0];  %because diff makes the vector one data point shorter.

if makePlots > 0
	figure, 
	ax(1)=subplot(3,1,1);
	plot(sig); title(plotTitles{1})

	ax(2)=subplot(3,1,2);
	plot(x); title(plotTitles{2})		

	ax(3)=subplot(3,1,3);
	plot(dx2); title(plotTitles{3})		
	linkaxes(ax,'x')
	zoom xon
end
wvonsets = find(dx > 0);
wvoffsets = find(dx < 0);

%figure out if an offset was at last frame of movie (no. of onsets and offsets not equal)
if wvonsets(1) > wvoffsets(1)
   wvonsets = [1 wvonsets];
end

if wvoffsets(end) < wvonsets(end)
   wvoffsets = [wvoffsets size(sig,2)];
end

if makePlots > 0 
	axes(ax(1))
	hold on
	plot(wvonsets,sig(wvonsets),'og');
	plot(wvoffsets,sig(wvoffsets),'or');

	axes(ax(2))
	hold on
	plot(wvonsets,x(wvonsets),'og');
	plot(wvoffsets,x(wvoffsets),'or');

	axes(ax(3))
	hold on
	plot(wvonsets,dx2(wvonsets),'og');
	plot(wvoffsets,dx2(wvoffsets),'or');
end

