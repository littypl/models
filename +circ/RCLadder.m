classdef RCLadder < models.BaseFullModel
% RCLadder: Model of a nonlinear resistor with independent current source
%
% This model has been used as benchmark in many papers. This implementation follows the details in
% [BS06] - Bai, Z., Skoogh, D.: A projection method for model reduction of bilinear dynamical systems.
% Linear Algebra and its Applications 415(2-3), 406?425 (2006)
%
% This model is also used in several papers dealing with MOR of nonlinear systems, i.e.
% [Re03] Rewienski, M.: A trajectory piecewise-linear approach to model order reduction of nonlinear
% dynamical systems. Ph.D. thesis, Citeseer (2003)
% or
% [CI04] M. Condon and R. Ivanov. Empirical balanced truncation of nonlinear systems. Journal of
% Nonlinear Science, 14:405?414, 2004. 10.1007/s00332-004-0617-5.
%
% @author Daniel Wirtz @date 2011-04-29
%
% @change{0,3,sa,2011-05-11} Implemented proeprty setter
%
% @new{0,3,dw,2011-04-29} Added this class.
%
% This class is part of the framework
% KerMor - Model Order Reduction using Kernels:
% - \c Homepage http://www.agh.ians.uni-stuttgart.de/research/software/kermor.html
% - \c Documentation http://www.agh.ians.uni-stuttgart.de/documentation/kermor/
% - \c License @ref licensing
    
    properties
        % The target dimension of the RC ladder circuit
        %
        % @propclass{data}
        Dims;
    end
    
    methods
        
        function this = RCLadder(dims)
            if nargin == 0
                dims = 30;
            end
            this.Dims = dims;
            
            this.registerProps('Dims');
            
            this.Name = 'RC Ladder circuit model';
            
            this.T = 1;
            this.dt = .0025;
            this.tau = 1;
            
            this.System = models.circ.RCLadderSys(this);
            
            % Only train with first input!
            this.TrainingInputs = [2 3];
            
            this.Sampler = [];
            
            a = approx.AdaptiveCompWiseKernelApprox;
            a.TimeKernel = kernels.NoKernel;
            a.ParamKernel = kernels.NoKernel;
            a.SystemKernel = kernels.GaussKernel(.5);
            a.MaxRelErr = 1e-5;
            a.MaxAbsErrFactor = 1e-3;
            a.NumGammas = 10;
            t = approx.selection.TimeSelector;
            t.Size = 12000;
            a.TrainDataSelector = t;
            this.Approx = a;
            
            s = spacereduction.PODReducer;
            s.Mode = 'abs';
            s.Value = 3;
            s.UseSVDS = false;
            this.SpaceReducer = s;
            
            s = solvers.ode.ExplEuler;
            s.MaxStep = .005; % Stability constraint due to diffusion term
            this.ODESolver = s;
        end
        
        function set.Dims(this, value)
            if ~isposintscalar(value)
                error('value must be a positive integer scalar');
            end
            this.Dims = value;
        end
    end
    
    methods(Static)
        function m = getTPWLVersion
            m = models.circ.RCLadder(100);
            m.T = 10;
            m.SpaceReducer.Mode = 'abs';
            m.SpaceReducer.Value = 10;
            %m.SpaceReducer = [];
            a = approx.TPWLApprox;
            a.TrainDataSelector.EpsRad = 0.02;%0.0059;
            m.Approx = a;
            m.TrainingInputs = 1;
        end
        
        function m = getSVRVersion
            m = models.circ.RCLadder(50);
            m.T = 2;
            m.System.Inputs(1) = [];
            m.SpaceReducer.Mode = 'abs';
            m.SpaceReducer.Value = 10;
            %m.SpaceReducer = [];
            a = approx.FixedCompWiseKernelApprox;
            a.Gammas = logspace(log10(.01),log10(10),30);
            c = general.regression.ScalarNuSVR;
            c.C = 500;
            c.nu = .4;
            c.QPSolver = solvers.qp.qpMosek;
            c.QPSolver.MaxIterations = 20000;
%             c = general.regression.KernelLS;
%             c.CGTol = c.CGTol;
%             c.lambda = 1;
%             c.CGMaxIt = 10000;
            a.CoeffComp = c;
            a.TimeKernel = kernels.NoKernel;
            a.ParamKernel = kernels.NoKernel;
            a.SystemKernel = kernels.GaussKernel(1);
            a.TrainDataSelector.Size = 200;
            m.Approx = a;
            m.TrainingInputs = 1;
        end
    end
    
end