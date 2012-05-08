function me71transmission
  clc, clear all, close all

  %% Code to study models for transmission design
  % Written by Brad Saund for ME71 at Caltech
  % Created from previous code for ME71 Transmission Contest
  % April 2012
  % brad.saund@gmail.com

  %% Modified by Team FAR
  % Rachel Hess
  % Alex Wilson
  % Fred Zhao
  % May 2012

  %% Transmission simulation

  % This code is intended to aid in determining the best gear ratio for your
  % transmission in the ME71 Transmission Contest. The rules should be
  % described in detail in another handout, but here is a brief description.
  %
  % A motor powers your transmission which powers a bicycle wheel. The wheel
  % is connected to a computer which records the speed of the wheel. The
  % simulation runs for Tmax (generally 180) seconds. Your score is the max
  % speed of the wheel (in RPM) divided by the time (in seconds) it takes the
  % wheel to reach 250 RPM.
  %
  % The first two variables are user defined, and are based on your
  % transmission.
  % Gear Ratio is the Gear Ratio of your transmission. A gear ratio > 1
  % indicates the electric motor will be spinning faster than the bicycle
  % wheel (which is generally the way you want to go).
  % mu is the estimated efficiency of your transmission. In reality mu
  % depends on what type of gearing is used (metal gears, plastic gears,
  % belts, friction...) and losses from bearings or bushings. Mu may vary
  % between 40% and 85% between different groups. (Hopefully no one has a mu
  % of 0...)
  %
  % Many of the global variables and a,b,c in WheelDrag() are experimentally
  % measured based on the setup in the shop. You may make your own
  % measurements to try to get more accurate numbers, though these should be
  % close.

  %% Instructions
  % Goal - Determine the optimal transmission coefficient for your
  % transmission
  %
  % 1. Make sure all of the experimentally determined values are correct.
  % These are the global variables as well as a,b,and c in the function
  % WheelDrag
  %
  % 2. Look at and understand the 5 plots currently outputed. Matlab will
  % use the data in these graphs, but you should be familiar with these
  % curves. Note: "Load" refers to the bicycle wheel. Look at the code for
  % plot[Drag,Torque,Accel,Profiles,Efficiency]. Try changing OmegaLoad to
  % just focus on the most important region. Note that OmegaLoad is in rad/s.
  %
  % 3. With GearRatio=1 and mu=1, we have a bar connecting the motor and
  % wheel (although even a bar would not have efficiency of exactly 1).
  % Change GearRatio and mu to model a transmission and try to get a good
  % score. Use the function TransmissionScore to calculate your score.
  % Look at the code to see how it does this.
  %
  % 4. When using computers, we don't want to have to try different gear
  % ratios and mus by hand, we want the computer to do it. Look at the
  % function plotScores. Give it a reasonable input that will tell you your
  % optimal gear ratio.
  %
  % 5. In practice you may not be able to get this exact gear ratio. After
  % you decide on a gear ratio, recalculate what your score will be given
  % different efficiencies.
  %
  % 6. Lastly, once your transmission is complete and you run it on the setup
  % and get a score, figure out the efficiency of your transmission.



  %%%%%%%%%
  % You will want to change these values
  GearRatio = 1;
  mu = 0.7;

  % For comparative analysis
  gearRatioVector = 1:.1:14;
  muVector = .5:.05:1.0;
  %%%%%%%%%

  RatedV = 24;
  OperatingV = 24;

  global RPMtoRAD;
  RPMtoRAD = 2 * pi / 60.0;
  global Tmax;
  Tmax = 180;

  %%%%%%%%%%%%
  % These values are specific to the test setup
  % Verify they are correct
  global StallTorque; % N*m
  StallTorque = (OperatingV / RatedV) * .150;
  global OmegaNoLoad; % rad/s
  OmegaNoLoad = (OperatingV / RatedV) * 3560 * RPMtoRAD;
  global WheelInertia; % kg*m/s^2
  WheelInertia = 0.167;
  global MotorInertia; % kg*m/s^2
  MotorInertia = 0.0000065;
  %%%%%%%%%%%%

  % plotDrag()
  % plotTorque(GearRatio)
  % plotAccel(GearRatio, mu)
  % plotProfiles(GearRatio, mu)
  % plotEfficiency(GearRatio, [.5,.6,.7,.8])


  %%%%%%%%%%%%
  % Comparative analysis

  % Plots scores for various efficiencies and gear ratios
  plotScores(gearRatioVector, muVector)
                                   
  [bestMaxSpeedRatios, maxSpeeds] = findBest(muVector, gearRatioVector, @MaxSpeed, @gt)
  plotMaxSpeed(bestMaxSpeedRatios, maxSpeeds)

  [bestMinTimeRatios, minTimes] = findBest(muVector, gearRatioVector, @TimeTo250RPM, @lt)
  plotFastest250(bestMinTimeRatios, minTimes)

  % For a given mu, the following code compares the shifting score with the 
  % non-shifting score.
  [bestFixedRatios, bestScores] = findBest(muVector, gearRatioVector, @TransmissionScore, @gt)

  for i = 1:length(muVector)
    mu = muVector(i);
    N = MaxSpeed(bestMaxSpeedRatios(i), mu) / RPMtoRAD;
    T = TimeTo250RPM(bestMinTimeRatios(i), mu);
    IdealShiftingScore = N / T;

    N = MaxSpeed(4, mu) / RPMtoRAD;
    T = TimeTo250RPM(12,mu);
    OurShiftingScores(i) = N / T;
  end

  % Matrix of improvements with rows being mu(shifting) and columns being mu(fixed)
  Improvements = (transpose(OurShiftingScores)) * (bestScores .^ (-1))


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


  function [drag] = WheelDrag(OmegaLoad)
    % Returns the Drag of the Wheel at angular velocity OmegaLoad
    % Drag is in N*m, velocity is in rad/s

    %%%%%%%%%%%
    % These values are specific to the test setup
    % Verify they are correct
    a = 0.0008407562206332089;
    b = 0.000029056995549246232;
    c = 7.296169057915168 * 10^-7;
    drag = a * OmegaLoad + b * OmegaLoad^2 + c * OmegaLoad^3;
    %%%%%%%%%%%
  end


  function [accel] = Acceleration(OmegaLoad, GearRatio, mu)
    % Returns the Acceleration of the wheel at angular velocity
    % OmegaLoad at a specific gear ratio and mu.

    accel = (mu * GearRatio * MotorTorque(GearRatio .* OmegaLoad) - WheelDrag(OmegaLoad)) / (GearRatio^2 * MotorInertia + WheelInertia);
  end


  function [torque] = MotorTorque(OmegaMotor)
    % Returns the Torque generated by the motor at motor angular
    % velocity
    % Torque is in N*m, velocity is in rad/s

    torque = StallTorque * (1 - OmegaMotor / OmegaNoLoad);
  end

  function [root] = MaxSpeed(GearRatio,mu)
    % Returns the Max Speed in rad/s of a wheel at a given gear ratio
    % and mu

    % This is found by setting the drag equal to the force from the
    % motor
    root = fzero(@(OmegaLoad) WheelDrag(OmegaLoad) - mu * GearRatio * MotorTorque(GearRatio * OmegaLoad), 0);
  end


  function [T, Y] = CreateProfile(GearRatio, mu)
    % Returns time and angular velocity (rad/s) of a wheel starting from
    % rest with a given gear ratio

    % This numerically solves the equation
    % d^2w/dt^2 = (torque - drag) / Inertia
    % T and Y are the time and angular velocity vectors of the
    % numberical solution of the bicycle wheel for this particular
    % transmission
    [T, Y] = ode45(@Omega, [0:.3:Tmax], [0], [], GearRatio, mu);

    function dy = Omega(t, y, GearRatio, mu)
      dy = Acceleration(y, GearRatio, mu);
    end
  end


  function [t250] = TimeTo250RPM(GearRatio, mu)
    % Returns the time it takes for the wheel to read 250RPM or TMax if
    % the wheel never reaches 250RPM

    [T, Y] = CreateProfile(GearRatio, mu);

    % Interpolate to find the time when 250 RPM is reached
    % This time cannot be greater than Tmax
    t250 = min(interp1(Y, T, 250 * RPMtoRAD), Tmax);
  end

  function [score] = TransmissionScore(GearRatio, mu)
    % Returns the Score of the transmission which is
    % MaxSpeed in RPM / Time to 250 RPM

    N = MaxSpeed(GearRatio, mu) / RPMtoRAD;
    T = TimeTo250RPM(GearRatio, mu);
    score = N / T;
  end



  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %% The Following Functions help create various plots


  function plotDrag()

    % Angular velocities plotted
    Omegaload = 0:.1:200 ;

    figure('Name', 'Wheel Drag v Speed');
    plot(Omegaload, arrayfun(@WheelDrag, Omegaload));
    xlabel('LoadSpeed [rad/s]');
    ylabel('Drag [N*m]');
    grid on
  end


  function plotTorque(GearRatio)

    % Angular velocities plotted
    Omegaload = 0:.1:200;

    figure('Name', 'Torque v Speed');
    plot(Omegaload, GearRatio * arrayfun(@MotorTorque, (GearRatio .* Omegaload)));
    xlabel('LoadSpeed [rad/s]');
    ylabel('Motor Torque [N*m]');
    grid on
  end


  function plotAccel(GearRatio,mu)

    % Angular velocities plotted
    Omegaload = 0:.1:200;

    figure('Name','Accel v Speed');
    plot(Omegaload, arrayfun(@Acceleration, Omegaload, GearRatio * ones(size(Omegaload)), mu * ones(size(Omegaload))));
    xlabel('LoadSpeed [rad/s]');
    ylabel('Acceleration [rad/s^2]');
    grid on
  end


  function plotProfiles(GearRatios,mu)
    % Plots Speed v Time for a vector of different gear ratios
    figure('Name', ['Speed v Time for various Gear Ratios with an efficiency of ' num2str(mu)]);

    for i = 1:length(GearRatios)
      [T, Y] = CreateProfile(GearRatios(i), mu);
      plot(T, 1/RPMtoRAD * Y);
      hold on
    end

    xlabel('Time [s]');
    ylabel('Load Speed [RPM]');
    title('Load Velocity v Time for various gear ratios');
  end


  function plotEfficiency(GearRatio, mus)
    % Plots Speed v Time for a specific gear ratio with different
    % efficiencies

    figure('Name', ['Speed v Time for various efficiencies with a gear ratio of ' num2str(GearRatio)]);

    for i = 1:length(mus)
      [T, Y] = CreateProfile(GearRatio, mus(i));
      plot(T, 1 / RPMtoRAD * Y);
      hold on
    end

    xlabel('Time [s]');
    ylabel('Load Speed [RPM]');
    title('Load Velocity vs. Time for various efficiencies');
  end


  function plotScores(GearRatios, mus)
    % Plots scores v gear ratios for a variety of efficiencies
    % It also gives the maximum gear ratio at each efficiency

    % This function can take some time to run

    fprintf('\nIn this set, the optimal gear ratio for mu of:\n')

    figure('Name','Scores for Various Gear Ratios and Efficiencies')
    hold on

    scores = zeros(1,length(GearRatios));
    for i = 1:length(mus)
      for j = 1:length(GearRatios)
        scores(j) = TransmissionScore(GearRatios(j), mus(i));
      end

      plot(GearRatios, scores);

      % find the index of the best score at this efficiency
      [s maxindex] = max(scores);

      fprintf([num2str(mus(i)) ' is ' num2str(GearRatios(maxindex)) '\n']);
    end

    xlabel('Gear Ratio');
    ylabel('Score');
    title('Scores for various Gear Ratios and Efficiencies');
  end


  function [best_y_x, best_z_yx] = findBest(x_, y_, z_yx, comparator)
    % Helper function that takes in a function z_xy(x, y),
    % vectors x_ and y_, and iterates over x_ and y_ respectively
    % to optimize z_xy using comparator. The results of the
    % optimization are stored in two output vectors, the first
    % that finds the value of y_ that optimizes z given an x, and
    % the second that holds that optimized z for the corresponding
    % index of the given x, i.e. z(x, arg_{y_j} max z(x, y_j))
    
    for i = 1:length(x_)
      for j = 1:length(y_)
        if (exist('best_z_yx') == 0) || (length(best_z_yx) < i)
          best_z_yx(i) = z_yx(y_(j), x_(i));
          best_y_x(i) = y_(j);
        else
          if (comparator(z_yx(y_(j), x_(i)), best_z_yx(i)) == 1)
            best_z_yx(i) = z_yx(y_(j), x_(i));
            best_y_x(i) = y_(j);
          end
        end
      end
    end

  end


  function [result] = gt(a, b)
    result = a > b;
  end

 
  function [result] = lt(a, b)
    result = a < b;
  end


  function plotMaxSpeed(bestRatios, maxSpeeds)
    % First plot Alex created for calculating shift points

    figure('Name','Max speeds for various gear ratios')
    hold on

    for i = 1:length(bestRatios)
      plot(bestRatios(i), maxSpeeds(i))
    end

    xlabel('Gear Ratio');
    ylabel('Max Speed');
    title('Max Speed as a Function of the Gear Ratio');
  end


  function plotFastest250(bestRatios, minTimes)
    % Second plot Alex created for calculating shift points

    figure('Name','Times to 250rpm for various gear ratios')
    hold on

    for i = 1:length(bestRatios)
      plot(bestRatios(i), minTimes(i))
    end

    xlabel('Gear Ratio');
    ylabel('Time to 250 RPM');
    title('Time to 250RPM as a Function of the Gear Ratio');
  end

end
