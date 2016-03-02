function [t,x]= project_template
%% Description, Authors, etc 
%{
    Write a brief description of your project. 
    -   What is your system ? 
    -   What the state variables ? 
    -   How do you control the system ? How many control inputs do you have ?
    -   What the goal of the control? What's the cost function ?
    -   What kind of process do you use to come upwith control policy ?

    Also, write you name 
%}
%  EXAMPLE for Description
%{
    This is a project template for "Numerical Optimal Control".

    System Description:
    This example uses a basic single degree-of-freedom spring-mass-damper
    system. There are 2 state variable, position of the block and velocity
    of the block. We assume that we can exert control force directly on the
    block. And there is only one control input.

    Problem Statement:
    The goal is to move the block to the desire position (5 meter from the
    wall). The block starts at 10 meter from the wall. The quadratic cost
    function is used to minimize the control effort.

    Control Methodology:
    Standard Linear Quadratic Regulator (LQR) is used to come up with a
    gain matrix K, which later is used for full state-feedback.

    Author: Pi Thanacha Choopojcharoen
%}
%% Parameters
%{
    This is where you assign all parameters in the system such as mass,
    length, spring constant.

    Use assignParameter to create a struct of parameters. Go to the function
    declaration and assign each parameter as seen in example
%}
field = [[0;0] [1000;0] [1000;1000] [0;1000]];
robot_local = [[-100;-50] [100;-50] [100;50] [-100;50]] ;
%obstacles = cat(3, [[800;0] [1000;0] [1000;200] [800;200]], [[800;800] [1000;800] [1000;1000] [800;1000]]);
obstacles = [[900;100;100] [800;200;200] [400;200;200]];
parameter = assignParameter(field,obstacles,robot_local);
%% Planner

L = @(x,u,t)(u(1,:).^2+100*u(2,:).^2); %v
M = @(x,T)(0);
v_max = 500; % mm/s
omega_max = 2; % rad/s
h = @(x,u)[bsxfun(@minus,abs(u),[v_max;omega_max]);detectCollisionCircles(x,parameter)];
%h = @(x,u)[bsxfun(@minus,abs(u),[v_max;omega_max])];

%h = @(x,u)[0];
e = 0.001; % error 
r = @(x,T) [(x-[900;500;pi/2]).^2 - e];
% try eq cons
f = @(x,u,t) dynamics(x,u,t,parameter);
f_ = @(x,u,t) dynamics_(x,u,t,parameter);
%x_0 = [ 100;100;pi/2 ];
x_0 = [ 200;150;pi/2 ];
T = 5;
N = 20;

m = 2; % number of control input
tic;
[x,u,t,J] = dirCol(L,M,h,r,f,x_0,m,T,N);
toc
%%
close all
figure;
X = x(t);
U = u(t);
subplot(2,1,1)
plot(t,X)
subplot(2,1,2)
plot(t,U)

%%

figure
hold on;
t_previous = -T/N;
for i = 1:size(parameter.obstacles,2)

end    
axis([0 1000 0 1000]);
axis equal;
for i = 1:size(X,2)
    robot_world = transform2d(X(:,i))*[parameter.robot_local;ones(1,size(parameter.robot_local,2))];

    xq = robot_world(1,:)';
    yq = robot_world(2,:)';
    
    p = fill(xq,yq,'g');
    axis([0 1000 0 1000])
    axis equal
    
    pause(t(i)-t_previous);
    t_previous = t(i);
    if i ~= size(X,2)
        delete(p);
    end
end

hold off;

%% Tracking
tic
[A,B] = linearizeAB(f_,x,u);
toc


Q = @(t)eye(3);
R = @(t)eye(2);
S = eye(3);
tic;
[K,P] = dare(A,B,Q,R,S,T,N);
toc
%%
u_track = @(x_real,t) -K(t)*(x_real - x(t))+u(t);

[t,X] = ode45(@(t,x)dynamics(x,u_track(x,t),t),[0 T],x_0 + [0.1;0.1;0.1]);

U = zeros(numel(u(0)),numel(t));
for i = 1:numel(t)
    U(:,i) = u_track(X(:,i),t(i));
end

figure
subplot(2,1,1); plot(t,X); xlabel('t');ylabel('x');
subplot(2,1,2); plot(t,U); xlabel('t');ylabel('u');

%% Control Policy
%{
    Your control policy should be defined inside the function declaration
    of controlAnalysis. Notice, the control policy is a function that
    depends on state variables (x) and time (t).
%}
u = @(x,t)controlAnalysis(x,t,parameter);

%% Dynamic System
%{
    Your dynamic system should be defined inside function declaration of
    dynamics. You have to transofrm your dynamic system into state-space
    representation.
%}
f = @(t,x)dynamics(x,u,t,parameter);

%% Simulation
%{
    This is where you set up your simulation parameter, such as final time
    (T), initial states (x_0). Note: final time might be determined from
    your control analysis if you have a problem with free final time.
%}

% T = 20;
% x_0 = [ 100;100;pi/2 ];
%[t,x] = ode45(f,[0 T],x_0);

%% visualization
%{
    You should define how to visualize your result inside a function
    visualization.
%}
%visualization(x,u,t,parameter);

end

%% detect collision with circles
function [ret] = detectCollisionCircles(x, parameter)
    % robot_world = mmat(transform2d(x),[parameter.robot_local;ones(1,size(parameter.robot_local,2))]);
    
    ob_size = numel(parameter.obstacles(1,:));
    t_size = size(x,2);
    ret = zeros(ob_size,t_size);
    
    for j = 1:t_size
        %xq = robot_world(1,:,j)';
        %yq = robot_world(2,:,j)';  
        xq = x(1);
        yq = x(2);
        
        for k = 1:ob_size
            ob = parameter.obstacles(:,k);
            xob = ob(1);
            yob = ob(2);
            rob = ob(3);
            ret(k,j) = rob^2 - ((xob-xq)^2 + (yob-yq)^2);
        end
    end
end

%% Detect collision
function [satisfyConstraint] = detectCollision(x, parameter)
% satisfyConstraint == -1 if good
    
    robot_world = mmat(transform2d(x),[parameter.robot_local;ones(1,size(parameter.robot_local,2))]);
    
    
%     xq = robot_world(1,:,:);
%     xq = permute(xq,[2 1 3]);
%     yq = robot_world(2,:,:);
%     yq = permute(yq,[2 1 3]);
    t_size = size(x,2);
    xvf = parameter.field(1,:)';
    yvf = parameter.field(2,:)';
    obstacle = zeros(1,t_size);
    field = zeros(1,t_size);
    satisfyConstraint = zeros(1,t_size);
    
    for j = 1:t_size
        xq = robot_world(1,:,j)';
        yq = robot_world(2,:,j)';        
        field(:,j) = numel(xq(inpolygon(xq,yq,xvf,yvf)));
        obstacleCount = 0;
        if (field(:,j) == numel(xvf))
            for i = 1:size(parameter.obstacles,3)
                ob = parameter.obstacles(:,:,i);
                xv = ob(1,:);
                yv = ob(2,:);
                obstacleCount = obstacleCount + numel(xq(inpolygon(xq,yq,xv,yv))) + numel(xv(inpolygon(xv,yv,xq,yq)));
            end
        end
        
        obstacle(:,j) = obstacleCount;
        
        if (field(:,j) == numel(parameter.robot_local(1,:))) && (obstacle(:,j) == 0)
            satisfyConstraint(:,j) = -1; % -1 < 0 so it will evaluate true in fmincon
        else
            satisfyConstraint(:,j) = 1;
        end
        
    end
    %satisfyConstraint
end

%% 2d transformation matrix
function result = transform2d(tr)
    theta = tr(3,:);
    theta = permute(theta,[1 3 2]);
    trx_  = permute(tr(1,:),[1 3 2]);
    try_  = permute(tr(2,:),[1 3 2]);
    result = [cos(theta) -sin(theta) trx_; sin(theta) cos(theta) try_; zeros(1,1,size(tr,2)) zeros(1,1,size(tr,2)) ones(1,1,size(tr,2))];
end

%% Dynamic Related Functions

function parameter = assignParameter(field,obstacles,robot_local)
%{
    You have to change each field of the struct according to your porject.
    This allows us to pass parameters easily to other functions.
%}
parameter.field = field;
parameter.obstacles = obstacles;
parameter.robot_local = robot_local;

end
function [m,b,k] = getParameter(parameter)
%{
    In addition to assignParameter, many functions require you to extract
    some specific parameters from the struct. Change this code, so that the
    parameters match with your project.
%}

m = parameter.field;
b = parameter.obstacles;
k = parameter.robot_local;

end

function dx = dynamics(x,u,t,parameter)
%{
    This is where you define your dynamic system. Make sure to include
    getParameter. Notice, u is a function of x and t.
%}
%[] = getParameter(parameter);
theta  = x(3,:);
v = u(1,:);
omega = u(2,:);
%dx = [cos(theta), 0; sin(theta), 0; 0, 1]*[v; omega];

dx = [cos(theta).*v; sin(theta).*v; omega];
end

function dx = dynamics_(x,u,t,parameter)
theta  = x(3);
v = u(1);
omega = u(2);

dx = [cos(theta)*v; sin(theta)*v; omega];
end
