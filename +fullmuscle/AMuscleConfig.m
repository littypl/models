classdef AMuscleConfig < models.muscle.AMuscleConfig
%     AMuscleConfig:
%     
%     Inherited model config with additional functionality.
%     
%     @author Daniel Wirtz @date 2014-09-17
%     
%     @new{0,7,dw,2014-09-17} Added this class.
%     
%     This class is part of the framework
%     KerMor - Model Order Reduction using Kernels:
%     - \c Homepage http://www.agh.ians.uni-stuttgart.de/research/software/kermor.html
%     - \c Documentation http://www.agh.ians.uni-stuttgart.de/documentation/kermor/
%     - \c License @ref licensing
    
    properties(SetAccess=private)
        % The different discrete fibre types this full muscle knows
        FibreTypes;
        
        forces_scaling;
        forces_scaling_poly = [-28.9060   53.8167  -24.1155   -7.2909    7.3932];
        
        SpindlePositions;
    end
    
    methods
        
        function this = AMuscleConfig(varargin)
            this = this@models.muscle.AMuscleConfig(varargin{:});
            % We always have a sarcomere version to choose for any
            % fullmuscle model
            this.addOption('SarcoVersion',1);
        end
        
        function m = createModel(this)
            % Convenience method
            m = models.fullmuscle.Model(this);
        end
        
        function configureModel(this, model)
            configureModel@models.muscle.AMuscleConfig(this, model);
            
%             nft = length(ft);
            
%             fe = this.PosFE;
%             geo = fe.Geometry;
%             SP = false(geo.NumElements,fe.GaussPointsPerElem, nft);
%             sp = this.getSpindlePos;
%             for k = 1:nft
%                 SP(sp(1,k),sp(2,k),k) = true;
%             end
            this.SpindlePositions = this.getSpindlePos;
        end
        
%         function configureModelFinal(this)
%             configureModelFinal@models.muscle.AMuscleConfig(this);
%         end
        
        function u = getInputs(this)
            % Returns the inputs `u(t)` of the model, if neumann boundary
            % conditions are used
            %
            % this.Model can be used to get access to the model this
            % configuration is applied to.
            %
            % Return values:
            % u: The cell array of input functions to use within this
            % model. @type cell @default {@(t)1}
            
            % First row is neumann input
            u{1,1} = this.getAlphaRamp(30,1);
            % Second row is external mean current input
            u{2,1} = @(t)1;
        end
        
    end
    
    methods(Access=protected)
        function dealWithFibreTypes(this, types)
            % Opposite to the normal muscle model behaviour, here we have a
            % built-in pool by the FirstOrderDynamics class. This only
            % needs the fibre types.
            this.FibreTypes = types;
            
            ftw = this.FibreTypeWeights;
            this.forces_scaling = 1./polyval(this.forces_scaling_poly,this.FibreTypes)';
            % Pre-scale the different weights so that the output of the
            % sarcomere models can directly be used and still alpha <= 1
            % comes out.
            this.FibreTypeWeights = bsxfun(@times,this.forces_scaling',ftw);
        end
    end
    
    methods(Abstract, Access=protected)
        sp = getSpindlePos(this);
    end
    
end