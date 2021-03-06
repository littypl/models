classdef AExperimentModelConfig < models.muscle.AMuscleConfig
    
    properties
        OutputDir = []; 
        ImgDir;
    end
    
    properties(Dependent)
        CurrentConfigNr;
    end
    
    properties(SetAccess=protected)
        NumConfigurations;
        NumOutputs;
        
        % The experimentally determined output values.
        % Must be a NumConfigurations x NumOutputs vector, if set.
        TargetOutputValues;
    end
    
    properties(Access=private)
        fCurConfNr = 1;
    end
    
    methods
        function this = AExperimentModelConfig(varargin)
            % Override in subclasses and set NumConfigurations to the
            % number of possible experiment runs with different IC/BCs.
            this = this@models.muscle.AMuscleConfig(varargin{:});
        end
        
        function set.CurrentConfigNr(this, nr)
            % Sets the configuration number.
            %
            % Use this in every overridden method to further specify
            % different behaviour
            if nr < 1 || nr > this.NumConfigurations
                error('Please choose one of the %d possible configurations.',this.NumConfigurations);
            end
            this.fCurConfNr = nr;
            if ~isempty(this.Model)
                this.Model.setConfig(this);
            end
        end
        
        function value = get.CurrentConfigNr(this)
            value = this.fCurConfNr;
        end
    end
    
    methods(Access=protected)
        function init(this)
            init@models.muscle.AMuscleConfig(this);
            
            % Also init directories to reasonable defaults
            if isempty(this.OutputDir)
                mc = metaclass(this);
                [~,n] = fileparts(which(mc.Name));
                % Put relative to models.muscle.Model class - that wont change
                % location!
                p = fullfile(fileparts(which('models.muscle.Model')),'..','..','data');
                outdir = fullfile(p,n);
                this.OutputDir = outdir;
            end
        end
    end
    
    methods
        function set.OutputDir(this, value)
            if ~isempty(value)
                Utils.ensureDir(value);
                this.OutputDir = value;
                this.ImgDir = fullfile(value,'img');%#ok
            end
        end
    end
    
    methods(Abstract)
        o = getOutputOfInterest(this, t, y);
    end
    
    %% IC comp stuff
    properties(SetAccess=protected)
        RequiresComputedInitialConditions = false;
    end
    
    properties
        ICCompMode;
    end
    
    methods
        function x0 = getX0(this, x0)
            if ~this.ICCompMode
                optstr = this.getOptionStr;
                s = load(fullfile(this.OutputDir,sprintf('IC_%s.mat',optstr)));
                % We assume to have an IC for each configuration (possibly)
                x0 = s.x0(:,this.CurrentConfigNr);
            end
        end
        
        function computeInitialConditions(this)
            if this.RequiresComputedInitialConditions
                this.ICCompMode = true;
                m = this.Model;
                file = fullfile(this.OutputDir,sprintf('IC_%s.mat',optstr));
                value = ~this.HasICComputation || exist(file,'file') == 2;
            end
        end
    end
    
end

