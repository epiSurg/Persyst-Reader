function [hdr, data] = readPersystLay(fileName, startIndex, lData, channels)
  %READPERSYSTLAY  Reads EEG data from Persyst .lay files.
  %
  % [HDR, DATA] = READPERSYSTLAY('fileName', STARTIDX, LDATA, CHANNELS)
  % reads the header information and data array from the specified file.
  % The STARTIDX is an integer specifying the first index that should be
  % returned, LDATA is the number of values per channel that should be
  % returned, and CHANNELS is a 1xn array of indices specifying the
  % channels that should be returned.
  %
  % If LDATA is an empty array. The method will return all values.
  %
  %   Example:
  %     [hdr, data] = readPersystLay('fileName', 1, 10000, 1:10)


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % Copyright 2013 Trustees of the University of Pennsylvania
  % 
  % Licensed under the Apache License, Version 2.0 (the "License");
  % you may not use this file except in compliance with the License.
  % You may obtain a copy of the License at
  % 
  % http://www.apache.org/licenses/LICENSE-2.0
  % 
  % Unless required by applicable law or agreed to in writing, software
  % distributed under the License is distributed on an "AS IS" BASIS,
  % WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  % See the License for the specific language governing permissions and
  % limitations under the License.
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  narginchk(1,4);
  nargoutchk(1, 2);
  returnAll = false;
  
  
  switch nargin
    case 1
      startIndex = 1;
      switch nargout
        case 1
          returnData = false;
        case 2
          returnAll = true;
          returnData = true;
        otherwise
          error('Incorrect number of output arguments.');
      end
    case 4      
      assert(nargout ==2, 'Incorrect number of output arguments.');
      returnData = true;
    otherwise
      error('Incorrect number of input arguments.');
  end

  % Check files
  [folder, file,ext] = fileparts(fileName);
  assert(strcmp(ext,'.lay'),'Select ''.lay'' file as the fileName.');
  
  % Create Header structure:
  h = fopen(fileName,'r');
  header = fscanf(h,'%c');
  
  % Get headers 
  [hdrs, hdrIdx] = regexp(header,'\[\w*\]','match');
  hdrIdx = [hdrIdx (length(header)+1)];
  
  hdrStruct = struct('FileInfo',[],'SampleTimes',[],'ChannelMap',[]);
  for iHdr = 1:length(hdrs)
    switch hdrs{iHdr}
      case '[FileInfo]'
        curStr = header((hdrIdx(iHdr) + length(hdrs{iHdr})):(hdrIdx(iHdr+1)-1) );
        a = regexp(curStr,'\s*(?<key>[^=]+)=(?<value>[^\n]+)','names');
        
        FileStruct = struct();
        for i = 1:length(a)
          switch a(i).key
            case {'File' 'FileType'}
              FileStruct.(a(i).key) = deblank(a(i).value);
            otherwise
              FileStruct.(a(i).key) = str2double(a(i).value);
          end
        end
        
        try
        aux = dir(fullfile(folder, sprintf('%s.dat',file)));
        FileStruct.nrSamples = aux.bytes/(FileStruct.WaveformCount*2);
        catch ME
          error('WaveformCount not specified in .lay file');
        end
        
        hdrStruct.FileInfo = FileStruct;
        
      case '[Patient]' 
        curStr = header((hdrIdx(iHdr) + length(hdrs{iHdr})):(hdrIdx(iHdr+1)-1) );
        a = regexp(curStr,'\s*(?<key>[^=]+)=(?<value>[^\n]+)','names');
        
        PatientStruct = struct();
        for i = 1:length(a)
          PatientStruct.(a(i).key) = deblank(a(i).value);
        end
        
        hdrStruct.Patient = PatientStruct;  
        
      case '[ChannelMap]'
        curStr = header((hdrIdx(iHdr) + length(hdrs{iHdr})):(hdrIdx(iHdr+1)-1) );
        a = regexp(curStr,'\s*(?<key>[^=]+)=(?<value>[^\n]+)','names'); 
        
        ChannelMap = struct();
        for i = 1:length(a)
          ChannelMap(i).index = str2double(a(i).value);
          splitName = regexp(a(i).key,'-','split');
          ChannelMap(i).channel = splitName{1};
          if length(splitName)>1
            ChannelMap(i).ref = splitName{2};
          end
        end
        
        hdrStruct.ChannelMap = ChannelMap;  
        
      case '[Comments]'
        curStr = header((hdrIdx(iHdr) + length(hdrs{iHdr})):(hdrIdx(iHdr+1)-1) );
        a = regexp(curStr,'(?<start>[0-9\.]+),(?<duration>[0-9\.]+),(?<misc1>[0-9\.]+),(?<misc2>[0-9\.]+),(?<comment>[^\r]+)','names');
        for i = 1: length(a)
          a(i).start = str2double(a(i).start);
          a(i).duration = str2double(a(i).duration);
          a(i).misc1 = str2double(a(i).misc1);
          a(i).misc2 = str2double(a(i).misc2);
          a(i).comment = deblank(a(i).comment);
          
        end
        
        hdrStruct.Comments = a;
        
      case '[SampleTimes]'
        % This defines epochs of continuous data. Time is seconds from
        % midnight.
        
        curStr = header((hdrIdx(iHdr) + length(hdrs{iHdr})):(hdrIdx(iHdr+1)-1) );
        a = regexp(curStr,'\s*(?<index>[^=]+)=(?<time>[^\n]+)','names');
        for i = 1: length(a)
          a(i).index = str2double(a(i).index) + 1; %Convert to 1 based indexing.
          a(i).time = str2double(a(i).time);
        end
        
        hdrStruct.SampleTimes = a;
        
      otherwise
        curStr = header((hdrIdx(iHdr) + length(hdrs{iHdr})):(hdrIdx(iHdr+1)-1) );
        a = regexp(curStr,'\s*(?<key>[^=]+)=(?<value>[^\n]+)','names');
        
        FileStruct = struct();
        for i = 1:length(a)
          FileStruct.(a(i).key) = deblank(a(i).value);
        end
        
        hdrStruct.(hdrs{iHdr}(2:end-1)) = FileStruct;
    end
  end
  
  hdr = hdrStruct;
  fclose(h);
  
  if returnData
    datFilePath = fullfile(folder, sprintf('%s.dat',file));
    assert(exist(datFilePath,'file')==2,'File Not Found.');
    
    nrTraces = hdr.FileInfo.WaveformCount;
    
    if returnAll
      nrTraces = hdrStruct.FileInfo.WaveformCount;
      lData = hdrStruct.FileInfo.nrSamples;
      channels = 1:nrTraces;
    else
      if isempty(lData)
        lData = hdrStruct.FileInfo.nrSamples;
      end
      if isempty(nrTraces)
        nrTraces = hdrStruct.FileInfo.WaveformCount;
        channels = 1:nrTraces;
      end
    end
    
    
    memmapOffset = (startIndex-1)*nrTraces * 2; % In bytes
    m = memmapfile(datFilePath, 'Format',{'int16' [nrTraces lData] 'x'}, ...
      'Offset',memmapOffset,'Repeat',1);
    
    % Check if continuous:
    
    % Find startIndex in hdr.SampleTimes
    if ~isempty(hdr.SampleTimes)
      allIndeces = [hdr.SampleTimes.index];
      startEpoch = find(allIndeces<=startIndex,1,'last');
      endEpoch = find(allIndeces<=(startIndex+lData-1),1,'last');
      
      data = struct('startTime',[],'values',[]);
      if startEpoch == endEpoch
        offset = (startIndex - hdr.SampleTimes(startEpoch).index) * ...
          (1/hdr.FileInfo.SamplingRate);
        data.startTime = hdr.SampleTimes(startEpoch).time + offset; 
        data.values = hdr.FileInfo.Calibration * m.Data.x(channels,:)';  
      else
        
        curFileIdx = 1;
        dataIdx = 1;
        for curEpoch = startEpoch:endEpoch
          curEpochIndex = hdr.SampleTimes(curEpoch).index;
          
          offset = (curFileIdx + startIndex - 1 - curEpochIndex) * ...
            (1/hdr.FileInfo.SamplingRate);
          
          if curEpoch < endEpoch
            curFileIdx2 = hdr.SampleTimes(curEpoch+1).index  - startIndex;
          else
            curFileIdx2 = lData;
          end
          
          data(dataIdx).startTime = hdr.SampleTimes(curEpoch).time + offset; 
          
          curData = m.Data.x(channels,curFileIdx:curFileIdx2)';
          
          data(dataIdx).values = hdr.FileInfo.Calibration * curData;
          
          curFileIdx = curFileIdx2 +1;
          dataIdx = dataIdx+1;

          
        end
      end
      
    else
      data = hdr.FileInfo.Calibration * m.Data.x(channels,:)';  
    end

  end
  
end
