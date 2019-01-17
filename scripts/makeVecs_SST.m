studyFolder = '~/Desktop/REV_scripts/behavioral/REV_SST/';
cd([studyFolder '/output/analysisReady/'])
numSubs = 144;
% numRuns = 4;
runs = [1 2 13 14];
repodir = '~/Desktop/REV_BxData/'; %edit this path for your local computer
exclude = [];
task = 'sst'; % *LEK
analysis = 'basic'; % *LEK

% These two codes should reflect what's in the response column of the Seeker variable
% You'll specify exceptions to this rule below
leftButton=91;
rightButton=94;
studyPrefix='REV'; % You'll use this in your analysisReady data filenames

buttonRuleExceptions = dlmread([studyFolder '/info/systematicWrongButtons.txt'],'\t');

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
numRuns = length(runs);

% List names of all conditions, assuming all exist *LEK
standardNames = {'CorrectGo' 'CorrectStop' 'FailedStop' 'Cue' 'FailedGo'};  
% FailedGo is a trash condition; includes both incorrect gos and failed gos (misses)
standardCondsPerRun = length(standardNames);

% Import sub x cond matrix specifying removed conditions *LEK
DIR.condsRemoved = '~/Desktop/flexibleConCreation/conInfo'; % CHANGE THIS
condsRemovedFile = [DIR.condsRemoved filesep 'condsRemoved_' task '_' analysis '.txt'];

% Initialize condsRemoved variable (to be edited + exported later) *LEK
numCols = numRuns*standardCondsPerRun;
condsRemoved = nan(numSubs,numCols);

% Initialize variable
FailedGoCount = nan(numSubs,numRuns);

for s=1:numSubs
    
    if find(exclude==s) % Leave excluded subject rows as NaN
        sprintf('sub %d excluded',s)
    else
        % Create subjectCode
        if s<10
            placeholder = '00';
        elseif s<100
            placeholder = '0';
        else placeholder = '';
        end
        
        subjectCode = [studyPrefix placeholder num2str(s)];
        
        for r=runs % For runs defined previously (scanning only here)
            filename = [studyPrefix '_sub' num2str(s) '_run' num2str(r) '.mat'];
            if exist(filename)
                load(filename)  % Load .mat
                
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
 
                fxFolder = [repodir 'names_onsets_durations/SST/'];
                if exist(fxFolder)==7 %do nothing
                else mkdir(fxFolder)
                end
                save([fxFolder 'sub-' subjectCode '_task-sst_acq-' num2str(r) '_onsets.mat'],'names','onsets','durations');
                
            end % file exists if 
        end % run loop
    end % subject exclusion if
end % subject loop

dlmwrite([studyFolder '/compiledResults/upTo' studyPrefix placeholder num2str(numSubs) '/initialCheck/FailedGoCount_scanning.txt'],FailedGoCount,'delimiter','\t');

% Export matrix of condsRemoved all subs, all runs *LEK
dlmwrite(condsRemovedFile,condsRemoved,'delimiter','\t');

clear