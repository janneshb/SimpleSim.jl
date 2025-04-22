# Quadrotor simulation in Julia

6-DoF quadrotor simulation framework in Julia for testing controllers.

### Prerequisites

- [Docker](https://www.docker.com/products/docker-desktop) installed on your system
- [Visual Studio Code](https://code.visualstudio.com/) with the [Remote - Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension

### Getting Started

1. Clone the repository
2. Open the project folder in VS Code
3. Select "Remote-Containers: Reopen in Container" from the command palette
4. Once the dev container is running, you can run the simulation with `julia quad_sim.jl`

### System architecture

```mermaid
flowchart TB
    %% External setpoints
    SP_pos["Position\n(x,y,z) Setpoint"]
    SP_vel["Velocity\n(x,y,z) Setpoint"]
    SP_att["Attitude\n(quat) Setpoint"]
    SP_yaw["Yaw\nSetpoint"]

    %% State estimates
    EKF2_pos["Estimated Position"]
    EKF2_vel["Estimated Velocity"]
    EKF2_att["Estimated Attitude"]
    EKF2_rate["Estimated Body Rates"]

    %% Controller blocks
    PosCtrl["Position Controller\nP-only\nInputs: SP_pos, EKF2_pos\nOutput: vel_sp"]
    VelCtrl["Velocity Controller\nPID\nInputs: SP_vel & vel_sp, EKF2_vel\nOutput: acc_sp"]
    AccelConv["Accel→Thrust & Attitude\nInputs: acc_sp\nOutputs: thrust_sp, att_sp"]
    AttCtrl["Attitude Controller\nP-on-quat→rate_sp\nInputs: att_sp, SP_att, SP_yaw, EKF2_att\nOutput: rate_sp"]
    RateCtrl["Angular Rate Controller\nK‑PID\nInputs: rate_sp, EKF2_rate\nOutput: torque_sp"]
    Mixer["Actuator Mixer\nInputs: torque_sp, thrust_sp\nOutput: motor_commands"]
    MotorCmd["Motor Commands"]

    %% Connections
    SP_pos --> PosCtrl
    EKF2_pos --> PosCtrl
    PosCtrl -->|vel_sp| VelCtrl
    SP_vel --> VelCtrl
    EKF2_vel --> VelCtrl
    VelCtrl -->|acc_sp| AccelConv
    AccelConv --> AttCtrl
    SP_att --> AttCtrl
    SP_yaw --> AttCtrl
    EKF2_att --> AttCtrl
    AttCtrl -->|rate_sp| RateCtrl
    EKF2_rate --> RateCtrl
    RateCtrl --> Mixer
    AccelConv --> Mixer
    Mixer --> MotorCmd
```