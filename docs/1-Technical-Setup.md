# Part 1: Technical Setup

## Requirements

In order to complete the challenge, the following are required to be installed and configured for
your local development environment (don't worry, we will walk you though this in the next section):

- [Git](https://git-scm.com/downloads)
- [homebrew](https://docs.brew.sh/)
- [Go](https://go.dev/doc/install) version 1.22+
- [Colima](https://github.com/abiosoft/colima)
- [DBeaver](https://dbeaver.io/download/) (or a different database viewer)
- [VSCode](https://code.visualstudio.com/) (or a different IDE)

## Installing Requirements

### Git

Git should already installed on your machine. You can confirm this by running:

```bash
# check git version
git --version
```

If you dont have git installed, the above command will prompt you to install it.

### Homebrew

For this tech challenge, we are assuming that you are developing on a Mac. As such, we will be using
homebrew to install a lot of dependencies.

Homebrew can be installed by running the following commands

```bash
# install homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# if you are on an Apple Silicone Mac, run the following to add homebrew to the PATH
(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> ~/.zprofile eval "$(/opt/homebrew/bin/brew shellenv)"

# validate that homebrew is correctly installed. You may need to restart your terminal first
brew doctor
```

### Go

Go can be installed using homebrew by running the following commands:

```bash
# install go
brew install go
 
# confirm go installation
go version
```

### Colima

Due do licencing restrictions, Docker Desktop cannot be installed on CapTech machines. As an
alternative, we recommend using colima, a CLI based docker engine, instead.

Colima and the docker engine can be installed with homebrew using the following commands:

```bash
# install colima with homebrew
brew install colima

# validate colima installation
colima --version

# install docker with homebrew
brew install docker
```

Once installed, you can start and stop colima using the following command:

```bash
# start colima
colima start

# stop colima
colima stop
```

> If you run into an error such as:
>
>`Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?`
>
>please reference
> this [help article](https://github.com/abiosoft/colima/blob/main/docs/FAQ.md#cannot-connect-to-the-docker-daemon-at-unixvarrundockersock-is-the-docker-daemon-running).

### DBeaver

DBeaver is a free database viewer that we can use to interact with our database using a GUI. There
are other tools that can be used instead, but DBeaver is a free option that we can install with
homebrew.

DBeaver can be installed by running the following commands:

```bash
# install DBeaver with homebrew
brew install --cask dbeaver-community
```

### VSCode

It is recommended to use [Visual Studio Code](https://code.visualstudio.com/) as your IDE while
working through this tech challenge. This is because Visual Studio has a rich set of extensions that
will aid you as you progress through the exercise. However, you are free to use your preferred IDE.

VSCode can be installed either manually by going to
the [VSCode website](https://code.visualstudio.com/) or by running the following commands:

```bash
# install VSCode with homebrew
brew install --cask visual-studio-code
```

After installing Visual Studio Code, you should head to the Extensions tab and install the following
extensions\*:

- [Go](https://marketplace.visualstudio.com/items?itemName=golang.Go)
- [PostgreSQL](https://marketplace.visualstudio.com/items?itemName=ms-ossdata.vscode-postgresql)

Other useful VS Code extensions include:

- [ENV](https://marketplace.visualstudio.com/items?itemName=IronGeek.vscode-env)

\*Note that you may have to restart VSCode after installing some extensions for them to take effect.

## Repository Setup

Create your own repository using the `Use this template` in the top right of the webpage. Make
yourself the owner, and give the repository the same name as the template (golang-techchallenge1).
Once your repository is cloned locally, you are all set to move on to the next step.

## Database Setup

In order to initialize the database, the following setup will be required.

- First, ensure that you have installed and configured Podman Desktop correctly. Then, open a
  terminal and run the following commands to start a podman instance:

```
podman machine init
podman machine start
```

- Next, pull the PostgreSQL image by running the following command:

```
podman pull docker.io/library/postgres:latest
```

- You are then able to create a Podman container to store the database in. Run the following command
  in your terminal:

```
podman run -d --name PostgresServer -e POSTGRES_USER=user -e POSTGRES_PASSWORD=goChallenge -e POSTGRES_DB=blogs -p 5432:5432 docker.io/library/postgres:latest
```

At this point, you will notice in Podman Desktop that a container has been created and running on
port 5432.

In order to initialize the database and provide default data, you will need to complete the
following steps. Make sure that your podman container is up and running prior to completing these
steps.

- First, open DBeaver and add a new connection, specifying PostgreSQL as the database type. Next,
  make sure that the host, port, database, and credentials match as below

```
Host: localhost
Port: 5432
Database: blogs
Username: user
Password: goChallenge
```

> ---
>
> NOTE: If this is your first time using DBeaver, it may require you to download a JDBC driver to
> continue. Just follow the steps provided to download the necessary driver to continue.
>
> ---

- Once you have connected to the database, open a new sql script. Then, copy and paste the SQL
  commands into the sql script from the `database_postgres_setup.sql` file under the `/database`
  directory. At this point, you have now initialized your database and are ready to continue.

## Create Go Module and Install Necessary Libraries

To create your go project, open a terminal in the root project directory and run the following
command, replacing `[name]` with your name.

```
go mod init github.com/[name]/blog
```

Next, run the following commands that will install the required libraries for the tech challenge.

```bash
go get github.com/caarlos0/env/v11
go get github.com/swaggo/http-swagger
go get github
go install github.com/swaggo/swag/cmd/swag@latest
```

## Next Steps

So far, you have set up the database, initiated the go application, and installed the necessary
libraries to complete this tech challenge. In part 2, we will go over the basics of creating a REST
API using the net/http library. We will also be connecting to our database to perform standard
read/write operations. Last, we'll create unit tests for our application to ensure we meet our
required 80% code coverage. Click [here](./2-REST-API-Walkthrough.md) to proceed to part 2. You also
have the option to skip the walkthrough if you are familiar with writing a REST API in Go. In that
case, click [here](./3-Challenge-Assignment.md) to proceed to part 3.
