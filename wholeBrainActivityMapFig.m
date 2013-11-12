function [A3proj] = wholeBrainActivityMapFig(region, frames, plotType, figType, stimuliToPlot)
%wholeBrainActivityMapFig(region, frames, plotType, figType, stimuliToPlot)
% Examples
%	wholeBrainActivityMapFig(region);
%	wholeBrainActivityMapFig(region, [], 1);
%	wholeBrainActivityMapFig(region, [300 1800], 2);
%	wholeBrainActivityMapFig(region, [], 1);
% INPUTS
% region -- region formatted data structure (as from CalciumDX, domains2region, etc) that includes CC and STATS data structures returned from wholeBrain_segmentation.m and wholeBrain_kmeans.m
% frames -- frames should be a vector containing two integers, the startFrame and endFrame for the range you want to plot
% plotType -- an integer of 1, 2, or 3 indicating the type of plot you want 
%	1: plot all detected components (true positive activity domains and false positive artifacts)
%	2: plot without false positive artifacts tagged in the STATS.descriptor variable in region.STATS
%	3: plot only the false positive artifacts
% figType -- an integer of 1, 2, or 3 indicating the type of figure you want 
%	1: Make a single subplot based on plotType all detected components (true positive activity domains and false positive artifacts)
%	2: Make a multiplot figure for true-false positive comparison plot, ignores the input for plotType
%	3: Make multiplot figures for n stimuli, of m stimuli types
%	4: Make multiplot figures with summary projections for m stimuli types on individual scales
%	5: Make multiplot figures with summary projections for m stimuli types on same normalized scale
%	6: Make multiplot figures with summary projections for m stimuli types on a differential normalized scale
% stimuliToPlot -- a two element integer vector indicating the indices, i of the region.stimuli{i} you want to plot
% James B. Ackman 2013-10-10 14:31:28

if (nargin < 2 || isempty(frames)), frames = []; end
if (nargin < 3 || isempty(plotType)), plotType = 1; end
if (nargin < 4 || isempty(figType)), figType = 1; end
if (nargin < 5 || isempty(stimuliToPlot)) && ~isempty(region.stimuli) && figType > 2, 
	stimuliToPlot=1:numel(region.stimuli); 
end

%------------------------------------------------------------------------

switch figType
	case 1
		[A3proj,frames] = wholeBrainActivityMapProj(region, frames, plotType);

		handles.figHandle = figure;
		set(handles.figHandle,'color','w');
		set(handles.figHandle, 'InvertHardCopy', 'off');   %so that black axes background will print
		handles.frames = frames;
		handles.axesHandle = subplot(1,1,1);
		handles.axesTitle = 'Signal px count norm to max sig count. MaxSig=';

		mx = max(A3proj(:));
		normValue = mx;

		img = A3proj./normValue;
		mxNormSig=max(img(:));
		
		disp(['max A3proj = ' num2str(mx)])
		disp(['mx normA3proj = ' num2str(mxNormSig)])
		
		handles.clims = [0 mxNormSig];
		wholeBrainActivityMapPlot(img, mxNormSig, handles, 20)

	case 2
		handles.figHandle = figure;

        scrsize = get(0,'screensize');
        set(handles.figHandle,'Position',scrsize);
        set(handles.figHandle,'color',[1 1 1]);
        set(handles.figHandle,'PaperType','usletter');
        set(handles.figHandle,'PaperPositionMode','auto');%         numplots = numel(stimuli{numStim}.stimulusParams);

		[Allproj,frames] = wholeBrainActivityMapProj(region, frames, 1);
		[Goodproj,frames] = wholeBrainActivityMapProj(region, frames, 2);
		[Badproj,frames] = wholeBrainActivityMapProj(region, frames, 3);
		handles.frames = frames;

		mxAllproj = max(Allproj(:)); 
		mxGoodproj = max(Goodproj(:));
		mxBadproj = max(Badproj(:));

		normValue = mxGoodproj;   %always normalize to the good map projection

		normAllproj = Allproj./normValue;
		mxNormAllproj=max(normAllproj(:));

		normGoodproj = Goodproj./normValue;
		mxNormGoodproj=max(normGoodproj(:));

		normBadproj = Badproj./normValue;
		mxNormBadproj=max(normBadproj(:));
		
		handles.clims = [0 max([mxNormAllproj mxNormGoodproj mxNormBadproj])];   %normalized to whatever the max one is

		disp(['max Allproj = ' num2str(mxAllproj)])		
		disp(['mx normAllproj = ' num2str(mxNormAllproj)])
		handles.axesHandle = subplot(1,3,1);
		handles.axesTitle = 'Signal px count norm to max sig count. MaxSig=';		
		wholeBrainActivityMapPlot(normAllproj, mxNormAllproj, handles);

		disp(['max Goodproj = ' num2str(mxGoodproj)])
		disp(['mx normGoodproj = ' num2str(mxNormGoodproj)])
		handles.axesHandle = subplot(1,3,2);
		handles.axesTitle = 'Signal px count norm to max sig count. MaxSig=';
		wholeBrainActivityMapPlot(normGoodproj, mxNormGoodproj, handles);

		disp(['max Badproj = ' num2str(mxBadproj)])
		disp(['mx normBadproj = ' num2str(mxNormBadproj)])
		handles.axesHandle = subplot(1,3,3);		
		handles.axesTitle = 'Noise px count norm to max sig count. MaxNoise=';
		wholeBrainActivityMapPlot(normBadproj, mxNormBadproj, handles);
		
	case 3
	
	%----start-------
	for numStim = stimuliToPlot
		nstimuli=1:numel(region.stimuli{numStim}.stimulusParams);
		name = region.stimuli{numStim}.description;

		disp('--------------------------------------------------')
		disp(name)
		h = figure;
		scrsize = get(0,'screensize');
        set(h,'Position',scrsize);
        set(h,'color',[1 1 1]);
        set(h,'PaperType','usletter');
        set(h,'PaperPositionMode','auto');%         numplots = numel(stimuli{numStim}.stimulusParams);

        numplots = numel(nstimuli);
        cols = 3;
        rows = floor(numplots/cols);
        if rem(numplots,cols) > 0
            rows = rows+1;
        end

		handles.figHandle = h;

		for i=1:numel(nstimuli)
			disp(['stimulus ' num2str(i)])

%            figure(handles.figHandle)
            ax(i) = subplot(rows,cols,i);
			handles.axesHandle = ax(i);
			handles.frames = [region.stimuli{numStim}.stimulusParams{i}.frame_indices(1) region.stimuli{numStim}.stimulusParams{i}.frame_indices(end)];
			[A3proj,frames] = wholeBrainActivityMapProj(region, handles.frames, plotType);

%			handles.axesTitle = 'Signal px count norm to max sig count. MaxSig=';

            if i==1
                handles.axesTitle = [name 'stim ' num2str(nstimuli(i)) ',MaxSig='];
            else
                handles.axesTitle = ['stim ' num2str(nstimuli(i)) ',MaxSig='];
            end

			mx = max(A3proj(:));
			normValue = mx;

			img = A3proj./normValue;
			mxNormSig=max(img(:));
		
			disp(['max A3proj = ' num2str(mx)])
			disp(['mx normA3proj = ' num2str(mxNormSig)])
		
			handles.clims = [0 mxNormSig];
			wholeBrainActivityMapPlot(img, mxNormSig, handles)
		end


	end
%--------end

	case 4  %individual scales
	%----start-------
		sz=region.domainData.CC.ImageSize;
		h = figure;
		scrsize = get(0,'screensize');
        set(h,'Position',scrsize);
        set(h,'color',[1 1 1]);
        set(h,'PaperType','usletter');
        set(h,'PaperPositionMode','auto');%         numplots = numel(stimuli{numStim}.stimulusParams);
		handles.figHandle = h;

		j = 0;
		for numStim = stimuliToPlot
			j = j+1;
			nstimuli=1:numel(region.stimuli{numStim}.stimulusParams);
			name = region.stimuli{numStim}.description;

			disp('--------------------------------------------------')
			disp(name)

			numplots = numel(stimuliToPlot);
			cols = 2;
			rows = floor(numplots/cols);
			if rem(numplots,cols) > 0
				rows = rows+1;
			end

			ax(j) = subplot(rows,cols,j);
			handles.axesHandle = ax(j);
		
			responseArray = zeros(sz(1),sz(2),length(nstimuli));
			responseArrayMax = [];

			for i=1:numel(nstimuli)
				disp(['stimulus ' num2str(i)])

				handles.frames = [region.stimuli{numStim}.stimulusParams{i}.frame_indices(1) region.stimuli{numStim}.stimulusParams{i}.frame_indices(end)];
				[A3proj,frames] = wholeBrainActivityMapProj(region, handles.frames, plotType);

	%			handles.axesTitle = 'Signal px count norm to max sig count. MaxSig=';

				mx = max(A3proj(:));
				responseArray(:,:,i) = A3proj;
				responseArrayMax(i) = mx;
			end

			handles.axesTitle = [name 'stim ' num2str(nstimuli(i)) ',MaxSig='];
			handles.frames = [];

			img = sum(responseArray,3);
			mx = max(img(:));
			img = img./mx;
		
			mxNormSig=max(img(:));
	
			disp(['max A3proj = ' num2str(mx)])
			disp(['mx normA3proj = ' num2str(mxNormSig)])
	
			handles.clims = [0 mxNormSig];
			wholeBrainActivityMapPlot(img, mxNormSig, handles)


		end
	%--------end


	case 5  %normalized scale
	%----start-------
		sz=region.domainData.CC.ImageSize;
		h = figure;
		scrsize = get(0,'screensize');
        set(h,'Position',scrsize);
        set(h,'color','w');
        set(h,'PaperType','usletter');
        set(h,'PaperPositionMode','auto');%         numplots = numel(stimuli{numStim}.stimulusParams);
        set(h, 'InvertHardCopy', 'off');   %so that black axes background will print
		handles.figHandle = h;

		numplots = numel(stimuliToPlot);
		cols = 2;
		rows = floor(numplots/cols);
		if rem(numplots,cols) > 0
			rows = rows+1;
		end


		j = 0;
		for numStim = stimuliToPlot
			j = j+1;
			nstimuli=1:numel(region.stimuli{numStim}.stimulusParams);
			name = region.stimuli{numStim}.description;

			disp('--------------------------------------------------')
			disp(name)
		
			responseArray{j} = zeros(sz(1),sz(2),length(nstimuli));
			responseArrayMax{j} = [];

			for i=1:numel(nstimuli)
				disp(['stimulus ' num2str(i)])

				handles.frames = [region.stimuli{numStim}.stimulusParams{i}.frame_indices(1) region.stimuli{numStim}.stimulusParams{i}.frame_indices(end)];
				[A3proj,frames] = wholeBrainActivityMapProj(region, handles.frames, plotType);

	%			handles.axesTitle = 'Signal px count norm to max sig count. MaxSig=';

				mx = max(A3proj(:));
				responseArray{j}(:,:,i) = A3proj;
				responseArrayMax{j}(i) = mx;
			end
	

		end

		sumCountPx = 0;
		sumCount = zeros(sz(1),sz(2));

		for j = 1:length(stimuliToPlot)
			tmp = sum(responseArray{j},3);
			sumCount = sumCount + tmp;
			sumCountPx = sumCountPx + sum(tmp(:));    %count of all activated pixels for the whole movie
		end

		for j = 1:length(stimuliToPlot)
			responseNorm{j} = sum(responseArray{j},3)./sumCountPx;
			MxresponseNorm(j) = max(responseNorm{j}(:));
		end

		mxNormSig = max(MxresponseNorm);
		handles.clims = [0 mxNormSig];
		
		j = 0;
		for numStim = stimuliToPlot
			j = j+1;

			name = region.stimuli{numStim}.description;
			ax(j) = subplot(rows,cols,j);
			handles.axesHandle = ax(j);


			handles.axesTitle = [name ',MaxSig='];
			handles.frames = [];

%			img = sum(responseArray{j},3);
%			img = img./sumCount;
%			img = img./mxNormSig;
			
%			mx = max(img(:));
%			img = img./mx;
	
%			disp(['max A3proj = ' num2str(mx)])
%			disp(['mx normA3proj = ' num2str(mxNormSig)])

			maxSig = MxresponseNorm(j);

%			handles.clims = [0 max([mxNormAllproj mxNormGoodproj mxNormBadproj])];
			wholeBrainActivityMapPlot(responseNorm{j}, maxSig, handles, 20)
		end

	case 6  %Differential plot with normalized scale
	%----start-------
		sz=region.domainData.CC.ImageSize;
		h = figure;
		scrsize = get(0,'screensize');
        set(h,'Position',scrsize);
        set(h,'color',[1 1 1]);
        set(h,'PaperType','usletter');
        set(h,'PaperPositionMode','auto');%         numplots = numel(stimuli{numStim}.stimulusParams);
		handles.figHandle = h;

		numplots = numel(stimuliToPlot);
		cols = 2;
		rows = floor(numplots/cols);
		if rem(numplots,cols) > 0
			rows = rows+1;
		end


		j = 0;
		for numStim = stimuliToPlot
			j = j+1;
			nstimuli=1:numel(region.stimuli{numStim}.stimulusParams);
			name = region.stimuli{numStim}.description;

			disp('--------------------------------------------------')
			disp(name)
		
			responseArray{j} = zeros(sz(1),sz(2),length(nstimuli));
			responseArrayMax{j} = [];

			for i=1:numel(nstimuli)
				disp(['stimulus ' num2str(i)])

				handles.frames = [region.stimuli{numStim}.stimulusParams{i}.frame_indices(1) region.stimuli{numStim}.stimulusParams{i}.frame_indices(end)];
				[A3proj,frames] = wholeBrainActivityMapProj(region, handles.frames, plotType);

	%			handles.axesTitle = 'Signal px count norm to max sig count. MaxSig=';

				mx = max(A3proj(:));
				responseArray{j}(:,:,i) = A3proj;
				responseArrayMax{j}(i) = mx;
			end
	

		end

		sumCountPx = 0;
		sumCount = zeros(sz(1),sz(2));

		for j = 1:length(stimuliToPlot)
			tmp = sum(responseArray{j},3);
			sumCount = sumCount + tmp;
			sumCountPx = sumCountPx + sum(tmp(:));    %count of all activated pixels for the whole movie
		end

		for j = 1:length(stimuliToPlot)
			responseNorm{j} = sum(responseArray{j},3)./sumCount;
			MxresponseNorm(j) = max(responseNorm{j}(:));
		end

		mxNormSig = max(MxresponseNorm);
		handles.clims = [0 mxNormSig];
		
		j = 0;
		for numStim = stimuliToPlot
			j = j+1;

			name = region.stimuli{numStim}.description;
			ax(j) = subplot(rows,cols,j);
			handles.axesHandle = ax(j);


			handles.axesTitle = [name ',MaxSig='];
			handles.frames = [];

%			img = sum(responseArray{j},3);
%			img = img./sumCount;
%			img = img./mxNormSig;
			
%			mx = max(img(:));
%			img = img./mx;
	
%			disp(['max A3proj = ' num2str(mx)])
%			disp(['mx normA3proj = ' num2str(mxNormSig)])

			maxSig = MxresponseNorm(j);

%			handles.clims = [0 max([mxNormAllproj mxNormGoodproj mxNormBadproj])];
			wholeBrainActivityMapPlot(responseNorm{j}, maxSig, handles)
		end

end


function handles = setupPlot(figHandle,nRows,nCols)
if nargin < 1 || isempty(figHandle), figHandle = figure; end
if nargin < 2 || isempty(nRows), nRows = 1; end
if nargin < 3 || isempty(nCols), nCols = 1; end

handles.figHandle = figHandle;

for i = 1:nRows
handles.ax(i) = subplot()
end

for i = 1:nCols

end
%}