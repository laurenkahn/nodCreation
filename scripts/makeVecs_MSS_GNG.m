studyCode = 'REV';
firstSub = 1;
lastSub = 144;

task = 'gng';
runs = [1 2 3 4];
DIR.dataRepo = ['~/Desktop/REV_BxData/']; % Edit this path 
analysis = 'prepost_analysis';
DIR.data = [DIR.dataRepo '/data/' task];

% List names of all conditions, assuming all exist 
standardNames = {'baseline' 'correct_risk_go' 'correct_risk_nogo' 'correct_neutral_go' 'correct_neutral_nogo' 'incorrect_risk_go' 'incorrect_risk_nogo' 'incorrect_neutral_go' 'incorrect_neutral_nogo'}; % baseline is crosshair and instructions
standardCondsPerRun = length(standardNames);

% Import sub x cond matrix specifying removed conditions
DIR.condsRemoved = '~/Desktop/flexibleConCreation/conInfo/'; % CHANGE THIS
condsRemovedFile = [DIR.condsRemoved filesep 'condsRemoved_' task '_' analysis '.txt'];
DIR.runsRemoved = [DIR.dataRepo '/info/']; 
runsRemovedFile = [DIR.runsRemoved filesep 'runsRemoved_' task '_' analysis '.txt'];

runsRemovedMat = dlmread(runsRemovedFile,'\t');

% Initialize condsRemoved variable (to be edited + exported later) *LEK
nSubs = lastSub-firstSub+1;
nCols = length(runs)*standardCondsPerRun;
condsRemoved = nan(nSubs,nCols);

% Initialize variable
FailedGoCount = nan(length(firstSub:lastSub), length(runs));

if ~(exist(DIR.data)==7)
    warning('data folder not found')
else
    for s = firstSub:lastSub
        if s<10
            placeholder = '00';
        elseif s<100
            placeholder = '0';
        else
            placeholder = '';
        end
        
        subject_code = [studyCode placeholder num2str(s)];
        
        for r = runs % For runs defined previously
            
            if runsRemovedMat(s,r) % if this run is the exclusion list
                sprintf('sub %d run %d excluded',s,r)
            else
                
                dataFile = [DIR.data filesep subject_code '_' task num2str(r) '.mat'];
                if ~(exist(dataFile)==2)
                    warning('No data file found for sub %d run %d',s,r)    
                else
                    load(dataFile)
                    
                    % Reassign tags based on correct/incorrect button press
                    for i = 1:length(run_info.responses)
                        currentTag = run_info.tag{i};
                        if isempty(run_info.responses{i})
                            if currentTag == '1'
                                run_info.tag{i} = '5';
                            elseif currentTag == '3'
                                run_info.tag{i} = '7';
                            end
                        end
                        
                        if ~isempty(run_info.responses{i})
                            if currentTag == '2'
                                run_info.tag{i} = '6';
                            elseif currentTag == '4'
                                run_info.tag{i} = '8';
                            end
                        end
                    end
                    
                    % Initialize names, onsets, durations variables
                    names = standardNames; % *LEK
                    onsets = cell(1,length(names));
                    durations = cell(1,length(names));
                    searchStrings = {'0' '1' '2' '3' '4' '5' '6' '7' '8'}; %% Need to fill this in
                    
                    for c = 1:length(names)
                        currentIndices = find(~cellfun(@isempty,regexp(run_info.tag,searchStrings{c})) == 1);
                        onsets{c} = run_info.onsets(currentIndices);
                        durations{c} = run_info.durations(currentIndices);
                    end
                    save(dataFile, 'key_presses', 'run_info')
                    
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
                    
                    DIR.nods = [DIR.dataRepo filesep 'names_onsets_durations/' task filesep analysis filesep];
                    if exist(DIR.nods)==7 %do nothing
                    else mkdir(DIR.nods)
                    end
                    save([DIR.nods 'sub-' subject_code '_task-' task '_acq-' num2str(r) '_onsets.mat'], 'names', 'onsets', 'durations') %Note that NODs files should be distinguished by acq number, NOT run number
                end
            end
        end
    end
end

% Export matrix of condsRemoved all subs, all runs *LEK
dlmwrite(condsRemovedFile,condsRemoved,'delimiter','\t');

clear
