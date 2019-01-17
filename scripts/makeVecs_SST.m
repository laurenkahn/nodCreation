% INPUT:
% systematicWrongButtons.txt specifying what wrong buttons subjects used systematically
% runsRemoved_task_analysis.txt specifying which runs should be excluded for which subjects

% OUTPUT:
% "nods" files - names, onsets, durations files - for use in first-level fMRI models
% condsRemoved_task_analysis.txt specifying which conds do not exist, for
% each run, for each subject. For integration with the flexibleConCreation
% repo

studyCode = 'REV'; % You'll use this in your analysisReady data filenames
firstSub = 1;
lastSub = 144;
runs = [1 2 13 14];

task = 'sst';
analysis = 'prepost_analysis';

DIR.dataRepo = ['~/Desktop/REV_BxData/']; % Edit this path
DIR.data = [DIR.dataRepo '/data/' task]; %

% List names of all conditions, assuming all exist
% Note: FailedGo is a trash condition; includes both incorrect gos and failed gos (misses)
standardNames = {'CorrectGo' 'CorrectStop' 'FailedStop' 'Cue' 'FailedGo'};
standardCondsPerRun = length(standardNames);

% Import sub x cond matrix specifying removed conditions
DIR.condsRemoved = '~/Desktop/flexibleConCreation/conInfo/'; % CHANGE THIS
condsRemovedFile = [DIR.condsRemoved filesep 'condsRemoved_' task '_' analysis '.txt'];
DIR.runsRemoved = [DIR.dataRepo '/info/'];
runsRemovedFile = [DIR.runsRemoved filesep 'runsRemoved_' task '_' analysis '.txt'];
% For testing only: 
% runsRemovedFile = [DIR.runsRemoved filesep 'runsRemoved_gng_' analysis '.txt'];

runsRemovedMat = dlmread(runsRemovedFile,'\t');

% Initialize condsRemoved variable (to be edited + exported later)
nSubs = lastSub-firstSub+1;
nRuns = length(runs);
nCols = nRuns*standardCondsPerRun;
condsRemoved = nan(nSubs,nCols);

% SPECIFY SST KEYS AND COLUMNS

% These two codes should reflect what's in the response column of the Seeker variable
% You'll specify exceptions to this rule below
leftButton=91;
rightButton=94;

% Specify where the systematicWrongButtons file lives:
buttonRuleExceptions = dlmread([DIR.dataRepo '/info/systematicWrongButtons.txt'],'\t');

% Some versions of the SST set up the Seeker variable differently.
% The script should tell you which columns are which and what different
% codes mean, but you can also deduce it from looking at the actual output.
% Change these to reflect your Seeker variable structure.
trialTypeColumn=3;
arrowDirColumn=4;
responseKeyColumn=7;
trialTimeColumn=12;
trialLengthColumn=15;
goCode=0;
stopCode=1;
leftCode=0;
rightCode=1;
arrowLength=1;

% Initialize variable
FailedGoCount = nan(nSubs,nRuns);

if ~(exist(DIR.data)==7)
    warning('data folder not found')
else
    for s=firstSub:lastSub
        % Create subjectCode
        if s<10
            placeholder = '00';
        elseif s<100
            placeholder = '0';
        else placeholder = '';
        end
        
        subjectCode = [studyCode placeholder num2str(s)];
        
        for r=runs % For runs defined previously (scanning only here)
            dataFile = [DIR.data filesep studyCode '_sub' num2str(s) '_run' num2str(r) '.mat'];
            if exist(dataFile)
                load(dataFile)  % Load .mat
                
                % Define LEFT and RIGHT *******
                problemSubIdx = find(buttonRuleExceptions(:,1)==s);
                problemRunIdx = find(buttonRuleExceptions(:,2)==r);
                probRow = intersect(problemSubIdx,problemRunIdx);
                
                if length(probRow)>1 % this shouldn't happen
                    warning('multiple button exception entries for sub %d run %d',s,r)
                end
                
                if isnan(buttonRuleExceptions(probRow,3))
                    % keep this run as NaNs (buttons were too inconsistent)
                else % start with default
                    LEFT=leftButton;
                    RIGHT=rightButton;
                    
                    if ~isempty(probRow)
                        LEFT = buttonRuleExceptions(probRow,3);
                        RIGHT = buttonRuleExceptions(probRow,4);
                        sprintf('button exception logged for sub %d run %d',s,r)
                    end
                end
                
                % Initialize names, onsets, durations variables *LEK edits
                names = standardNames;
                onsets = cell(1,standardCondsPerRun);
                durations = cell(1,standardCondsPerRun);
                
                
                % Get vectors of trial info
                trialType = Seeker(:,trialTypeColumn); % 0=Go, 1=NoGo, 2=null, 3=notrial`
                arrowDir = Seeker(:,arrowDirColumn); % 0=left, 1=right, 2=null
                responseKey = Seeker(:,responseKeyColumn);
                trialTime = Seeker(:,trialTimeColumn);
                trialLength = Seeker(:,trialLengthColumn);
                cueLength = trialLength - 1;
                
                % Add jitter column to Seeker
                numSeekerCols = size(Seeker,2);
                numSeekerRows = size(Seeker,1);
                Seeker(:,numSeekerCols+1) = NaN;
                
                % Find first non-null event in Seeker
                initialTrialIdx = find(~(Seeker(:,trialTypeColumn)==2),1);
                
                % To Beep Or Not To Beep
                isGo = trialType==goCode;
                isStop = trialType==stopCode;
                
                % Arrow presented
                isLeft = arrowDir==leftCode;
                isRight = arrowDir==rightCode;
                
                % Button response
                isLeftKey = responseKey==LEFT;
                isRightKey = responseKey==RIGHT;
                isNoResponse = responseKey==0;
                
                isCorrect = isLeft&isLeftKey | isRight&isRightKey;
                isPressed = isLeftKey|isRightKey;
                
                %%%%% Find Important Trial Types
                isCorrectGo = isGo&isCorrect; % Hits
                isCorrectStop = isStop&isNoResponse; % Correct Rejections
                isFailedStop = isStop&isPressed; % False Alarms (even if it's the wrong button)
                isIncorrectGo = (isGo&isNoResponse)|(isGo&(~isCorrect));% Misses or "wrong" direction hits - will be assigned to FailedGo
                
                
                %%%%% The Important Variables %%%%%
                onsets{1} = trialTime(isCorrectGo)+cueLength(isCorrectGo);
                onsets{2} = trialTime(isCorrectStop)+cueLength(isCorrectStop);
                onsets{3} = trialTime(isFailedStop)+cueLength(isFailedStop);
                onsets{4} = trialTime(isCorrectGo|isCorrectStop|isFailedStop|isIncorrectGo);
                onsets{5} = trialTime(isIncorrectGo)+cueLength(isIncorrectGo);
                FailedGoCount(s,r)=sum(isIncorrectGo);
                
                durations{1} = arrowLength;
                durations{2} = arrowLength;
                durations{3} = arrowLength;
                %                 durations{4} = nan(length(onsets{4}),1);
                %                 durations{4}(:) = .5;
                durations{4} = cueLength(isCorrectGo|isCorrectStop|isFailedStop|isIncorrectGo);
                durations{5} = arrowLength;
                
                % Determine which conditions to remove *LEK
                currentCondsRemoved = cellfun('isempty',onsets);
                
                % Remove empty onsets/durations vectors + associated names *LEK
                names = names(~currentCondsRemoved);
                onsets = onsets(~currentCondsRemoved);
                durations = durations(~currentCondsRemoved);
                
                % Insert list of condsRemoved for this run into condsRemoved variable *LEK
                startCol = 1 + (r-1)*standardCondsPerRun;
                endCol = r*standardCondsPerRun;
                condsRemoved(s,startCol:endCol) = currentCondsRemoved;
                
                DIR.nods = [DIR.dataRepo 'names_onsets_durations/' task filesep analysis filesep];
                if exist(DIR.nods)==7 %do nothing
                else mkdir(DIR.nods)
                end
                save([DIR.nods 'sub-' subjectCode '_task-sst_acq-' num2str(r) '_onsets.mat'],'names','onsets','durations');
                
            end % file exists if
        end % run loop
    end % subject loop
end % data folder exist check


dlmwrite([DIR.dataRepo '/info/FailedGoCount_scanning.txt'],FailedGoCount,'delimiter','\t');

% Export matrix of condsRemoved all subs, all runs *LEK
dlmwrite(condsRemovedFile,condsRemoved,'delimiter','\t');

clear