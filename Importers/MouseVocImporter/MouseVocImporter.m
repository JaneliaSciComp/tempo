classdef MouseVocImporter < FeaturesImporter
    
    properties
    end
    
    
    methods(Static)
        
        function n = typeName()
            n = 'Mouse Vocalization';
        end
        
        function ft = possibleFeatureTypes()
            ft = {'Vocalization'};
        end
        
        function c = canImportFromPath(featuresFilePath)
            c = false;
            
            if exist(featuresFilePath, 'file')
                [~, name, ext] = fileparts(featuresFilePath);
                if strcmp(ext, '.voc') || strcmp([name ext],'voc.txt')
                    voclist=load(featuresFilePath,'-ascii');
                    if size(voclist,2) == 4
                        c = true;
                    end
                elseif strcmp(ext,'.fc') || strcmp(ext,'.fc2')
                    voclist=load(featuresFilePath,'-mat');
                    if (strcmp(ext,'.fc') && iscell(voclist.freq_contours)) || ...
                        (strcmp(ext,'.fc2') && iscell(voclist.freq_contours2))
                        c = true;
                    end
                end
            end
        end
    end
    
    
    methods
        
        function obj = MouseVocImporter(controller, featuresFilePath)
            obj = obj@FeaturesImporter(controller, featuresFilePath);
        end
        
        
        function features = importFeatures(obj)
            features = {};
            hotPixels={};

            obj.updateProgress('Loading events from file...', 0/2)
            [~, name, ext] = fileparts(obj.featuresFilePath);
            if strcmp(ext, '.voc') || strcmp([name ext],'voc.txt')
              s = load(obj.featuresFilePath, '-ascii');

              [p,n,~]=fileparts(obj.featuresFilePath);
              axFiles=dir(fullfile(p,[n '*.ax']));
              for i=1:length(axFiles)
                try
                  FS=h5readatt(fullfile(p,axFiles(1).name),'/hotPixels','FS');
                  NFFT=h5readatt(fullfile(p,axFiles(1).name),'/hotPixels','NFFT');
                  dT=NFFT/FS/2;
                  dF=FS/NFFT/10;  % /10 for brown-puckette
                  data=h5read(fullfile(p,axFiles(1).name),'/hotPixels');
                catch
                  fid=fopen(fullfile(p,axFiles(i).name),'r');
                  fread(fid,3,'uint8');
                  fread(fid,2,'uint32');
                  dT=ans(2)/ans(1)/2;
                  fread(fid,2,'uint16');
                  fread(fid,2,'double');
                  dF=ans(2);
                  data=fread(fid,[4 inf],'double');
                  data=data';
                  fclose(fid);
                end
                data(:,1)=data(:,1)*dT;
                hotPixels{i}={data(:,[1 2 4]), dT, dF};
              end
            
            elseif strcmp(ext,'.fc') || strcmp(ext,'.fc2')
              data = load(obj.featuresFilePath,'-mat');
              if strcmp(ext,'.fc')
                data = data.freq_contours;
              else
                data = data.freq_contours2;
              end
              s=[];
              for i=1:length(data)
                bbhigh = cellfun(@(x) max(x,[],1)',data{i},'uniformoutput',false);
                bblow = cellfun(@(x) min(x,[],1)',data{i},'uniformoutput',false);
                bbhigh = max([bbhigh{:}],[],2);
                bblow = min([bblow{:}],[],2);
                s(end+1,:) = [bblow(1) bbhigh(1) bblow(2) bbhigh(2)];
              end

              foo = cellfun(@(x) [x{:}; nan(1,size(x{:},2))]', data, 'uniformoutput', false);
              foo = [foo{:}]';
              if strcmp(ext,'.fc')
                hotPixels{1} = foo(:,[1 2]);
              else
                hotPixels{1} = foo(:,[1 2 4]);
              end
            end
            
            obj.updateProgress('Adding events...', 1/2)
            for i = 1:size(s, 1)
                if((i==1) && ~isempty(hotPixels))
                  features{end + 1} = Feature('Vocalization', s(i,1:4), ...
                                    'HotPixels', hotPixels); %#ok<AGROW>
                else
                  features{end + 1} = Feature('Vocalization', s(i,1:4)); %#ok<AGROW>
                end
            end
        end
        
    end
    
end
