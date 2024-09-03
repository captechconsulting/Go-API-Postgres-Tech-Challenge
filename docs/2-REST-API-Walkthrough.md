# Part 2: REST API Walkthrough

## Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Database Setup](#database-setup)
  - [Configure the Connection to the Database](#configure-the-connection-to-the-database)
  - [Load and Validate the Environment Variables](#load-and-validate-the-environment-variables)
  - [Make a Utility Function to Connect to PostgreSQL](#make-a-utility-function-to-connect-to-postgresql)
  - [Test the Connection to the Database](#test-the-connection-to-the-database)
  - [Setting up User Model](#setting-up-user-model)
  - [Setting up User Utilities](#setting-up-user-utilities)
- [Service Setup](#service-setup)
  - [Defining Models](#defining-models)
  - [Implementing UserService Methods](#implementing-userservice-methods)
- [Server Setup](#server-setup)
  - [routes.go Setup](#routesgo-setup)
  - [user.go Setup](#usergo-setup)
  - [Gin Engine Setup](#gin-engine-setup)
  - [Generating Swagger Docs](#generating-swagger-docs)
  - [main.go Setup and Running Application](#maingo-setup-and-running-application)
- [Unit Testing](#unit-testing)
  - [Unit Testing Introduction](#unit-testing-introduction)
  - [Unit Testing in This Tech Challenge](#unit-testing-in-this-tech-challenge)

## Overview

As previously mentioned, this challenge is centered around the use of the `net/http` library for developing API's. Our web server will connect to a PostgreSQL database in the backend. This walkthrough will consist of a step-by-step guide for creating the REST API for the `users` table in the database. By the end of the walkthrough, you will have endpoints capable of creating, reading, updating, and deleting from the `users` table.

## Project Structure

By default, you should see the following file structure in your root directory

```
.
├── cmd/
│   └── api/
│       └── main.go
├── internal/
│   ├── config/
│   │   └── config.go
│   ├── handlers
│   ├── routes/
│   │   └── routes.go
│   └── services/
│       └── user.go
├── .gitignore
├── Makefile
└── README.md
```

Before beginning to look through the project structure, ensure that you first understand the basics of Go project structuring. As a good starting place, check out [Organizing a Go Module](https://go.dev/doc/modules/layout) from the Go team. It is important to note that one size does not fit all Go projects. Applications can be designed on a spectrum ranging from very lean and flat layouts, to highly structured and nested layouts. This challenge will sit in the middle, with a layout that can be applied to a broad set of Go applications.

The `cmd/` folder contains the entrypoint(s) for the application. For this Tech Challenge, we will only need one entrypoint into the application, `api`.

The `cmd/api` folder contains the entrypoint code specific to setting up a webserver for our application. This code should be very minimal and is primarily focused on initializing dependencies for our application then starting the application.

The `internal/` folder contains internal packages that comprise the bulk of the application logic for the challenge:

- `config` contains our application configuration
- `handlers` contains our http handlers which are the functions that execute when a request is sent to the application
- `models` contains domain models for the application
- `routes` contains our route definitions which map a URL to a handler
- `services` contains our service layer which is responsible for our application logic

The `Makefile` contains various `make` commands that will be helpful throughout the project. We will reference these as they are needed. Feel free to look through the `Makefile` to get an idea for what's there or add your own make targets.

Now that you are familiar with the current structure of the project, we can begin connecting our application to our database.

## Database Setup

We will first begin by setting up the database layer of our application.

### Configure the Connection to the Database

In order for the project to be able to connect to the PostgreSQL database, we first need to handle configuration.

First, create a `.env` file at the root of the project to contain environment variables, including the credentials required for the Postgres image.

```
POSTGRES_HOST=127.0.0.1
POSTGRES_USER=user
POSTGRES_PASSWORD=goChallenge
POSTGRES_DB=blogs
POSTGRES_PORT=5432
PORT=8000
CLIENT_ORIGIN=http://localhost:3000
```

### Load and Validate Environment Variables

To handle loading environment variables into the application, we will utilize the `env` package from `caarlos0` as well as the `godotenv` package.

If you have not already done so, download these packages by running the following command in your terminal:

```sh
go get github.com/caarlos0/env/v11 github.com/joho/godotenv
```

`env` is used to parse values from our system environment variables and map them to properties on a struct we've defined. `env` can also be used to perform validation on environment variables such as ensuring they are defined and don't contain an empty value.

`godotenv` is used to load values from `.env` files into system environment variables. This allows us to define these values in a `.env` file for local development.

Now, find the `internal/config/config.go` file. This is where we'll define the struct to contain our environment variables.

Add the struct definition below to the file:

```go
// Config holds the application configuration settings. The configuration is loaded from
// environment variables.
type Config struct {
	DBHost         string `env:"POSTGRES_HOST,required"`
	DBUserName     string `env:"POSTGRES_USER,required"`
	DBUserPassword string `env:"POSTGRES_PASSWORD,required"`
	DBName         string `env:"POSTGRES_DB,required"`
	DBPort         string `env:"POSTGRES_PORT,required"`
	ServerPort     string `env:"PORT,required"`
	ClientOrigin   string `env:"CLIENT_ORIGIN,required"`
}
```

Now, add the following function to the file:

```go
// New loads configuration from environment variables and a .env file, and returns a
// Config struct or error.
func New() (Config, error) {
	// Load values from a .env file and add them to system environment variables.
	// Discard errors coming from this function. This allows us to call this
	// function without a .env file which will by default load values directly
	// from system environment variables.
	_ = godotenv.Load()

	// Once values have been loaded into system env vars, parse those into our
	// config struct and validate them returning any errors.
	cfg, err := env.ParseAs[Config]()
	if err != nil {
		return Config{}, fmt.Errorf("[in config.New] failed to parse config: %w", err)
	}

	return cfg, nil
}
```

In the above code, we created a function called `New()` that is responsible for loading the environment variables from the `.env` file, validating them, and mapping them into our `Config` struct.

The `New` naming convention is widely established in Go, and is used when we are returning an instance of an object from a package that shares the same name. Such as a `Config` object being returned from a `config` package.

### Creating a `run` function to initialize dependencies

Now that we can load config, let's take a step back and make an update to our `cmd/api/main.go` file. One quirk of Go is that our `func main` can't return anything. Wouldn't it be nice if we could return an error or a status code from `main` to signal that a dependency failed to initialize? We're going to steal a pattern popularized by Matt Ryer to do exactly that.

First, in `cmd/api/main.go` we're going to add the function below:

```go
func run(ctx context.Context, w io.Writer) error {
	ctx, cancel := signal.NotifyContext(ctx, os.Interrupt)
	defer cancel()
	// We'll initialize dependencies here as we go...

	return nil
}
```

Next, we'll update `func main` to look like this:

```go
func main() {
	ctx := context.Background()
	if err := run(ctx, os.Stdout); err != nil {
		fmt.Fprintf(os.Stderr, "%s\n", err)
		os.Exit(1)
	}
}
```

Now our `main` function is only responsible for calling `run` and handling any errors that come from it. And our `run` function is responsible for initializing dependencies and starting our application. This consolidates all our error handling to a single place, and it allows us to write unit tests for the `run` function that assert proper outputs.

For more information on this pattern see this excellent [blog post](https://grafana.com/blog/2024/02/09/how-i-write-http-services-in-go-after-13-years/) by Matt Ryer.

### Connect to PostgreSQL

Next, we'll connect our application to our PostgreSQL server. We'll leverage the `run` function we just created as the spot to load our variables and initialize this connection.

To initialize our connection we're going to use the `gorm` package and it's underlying `postgres` driver. For more advanced DB connection logic (such as leveraging retries, backoffs, and error handling) you may want to create a separate database package.

First, download the `gorm` package:

```sh
go get -u gorm.io/gorm gorm.io/driver/postgres
```

Then, in the `cmd/api/main.go` file, update `run` to contain the snippet below:

```go
// ... other code from run

// Load and validate environment config
cfg, err := config.New()
if err != nil {
	return fmt.Errorf("[in main.run] failed to load config: %w", err)
}

// Create a new DB connection using environment config
db, err := gorm.Open(
	postgres.Open(
		fmt.Sprintf(
			"host=%s user=%s password=%s dbname=%s port=%s sslmode=disable TimeZone=UTC",
			config.DBHost,
			config.DBUserName,
			config.DBUserPassword,
			config.DBName,
			config.DBPort,
		)
	),
	&gorm.Config{})

if err != nil {
	return fmt.Errorf("[in main.run] failed to open database: %w", err)
}

log.Println("onnected successfully to the database")

// ... other code from run
```

At this point, you can now test to see if you application is able to successfully connect to the Postgres database. To do so, open a terminal in the project root directory and run the command `go run main.go`. You should see the following output:

```sh
Connected Successfully to the database
```

Congrats! You have managed to connect to your Postgres database from your application.

If your application is unable to connect to the database, ensure that the podman container for the database is running. Additionally, verify that the environment variables set up in previous steps are being loaded correctly.

### Setting up User Model

Now that we can connect to the database we'll set up our user domain model. This model is our internal, domain specific representation of a User. Effectively it represents how a User is stored in our database.

Create a `user.go` file in the `internal/models` package. Add the following struct:

```go
type User struct {
	ID       uint   `json:"id"`
	Name     string `json:"name"`
	Email    string `json:"email"`
	Password string `json:"password"`
}
```

### Creating our User Service

Next, we'll begin to build out the service layer in our application. Our service layer is where all of our application logic (including database access) will live. It's important to remember that there are many ways to structure Go applications. We're following a very basic layered architecture that places most of our logic and dependencies in our services. This allows our handlers to focus on request and response logic, and gives us a single point to find application logic.

Start by creating a new `users.go` file in the `internal/services` package. This file will hold the definitions for our user service.

Next, add the following struct, constructor function, and methods to the `users.go` file:

```go
// UsersService is a service capable of performing CRUD operations for
// models.User models.
type UsersService struct {
	logger *slog.Logger
	db 		 *gorm.DB
}

// NewUsersService creates a new UsersService and returns a pointer to it.
func NewUsersService(logger *slog.Logger, db *gorm.DB) *UsersService {
	return &UsersService{
		logger: logger,
		db: db,
	}
}

// CreateUser attempts to create the provided user, returning a fully hydrated
// models.User or an error.
func (s *UsersService) CreateUser(user models.User) (models.User, error) {
	return models.User{}, nil
}

// ReadUser attempts to read a user from the database using the provided id. A
// fully hydrated models.User or error is returned.
func (s *UsersService) ReadUser(id uint64) (models.User, error) {
	return models.User{}, nil
}

// UpdateUser attempts to perform an update of the user with the provided id,
// updating, it to reflect the properties on the provided patch object. A
// models.User or an error.
func (s *UsersService) UpdateUser(id uint64, patch models.User) (models.User, error) {
	return models.User{}, nil
}

// CreateUser attempts to create the provided user, returning a fully hydrated
// models.User or an error.
func (s *UsersService) DeleteUser(id uint64) error {
	return nil
}

// CreateUser attempts to create the provided user, returning a fully hydrated
// models.User or an error.
func (s *UsersService) ListUsers(id uint64) ([]models.User, error) {
	return []models.User{}, nil
}
```

Now we've stubbed out a basic `UsersService` capable of performing CRUD on our User model. Next we'll flesh out the `Read` method.

Update the `Read` method to below:

```go
func (s *UsersService) Read(id uint64) (User, error) {
	var user User

	if err := s.db.First(&user, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return user, nil
		}
		return user, fmt.Errorf("[in services.UserService.Read] failed to read user: %w", err)
	}

	return user, nil
}
```

Let's quickly walk through the structure of this method, as it will serve as a sort of template for other similar methods:

- First, a `user` var is created, which will hold the information of the user we search for
- Next, the information of the user is retrieved using the `First` method on our database connection. For documentation on this and other similar methods, see the Gorm docs [here](https://gorm.io/docs/query.html). Note that we pass a pointer for the `user` var we declared so that the information can be bound to the object.
- Next, we check if there was an error retrieving the information, and if there was, we wrap the error and return it
- If there was no error, we return the `user`

Now, go through an implement the other CRUD methods.

These methods should leverage the `Where`, `First`, `Create`, `Model`, `Updates`, and `Delete` methods on the `db` object on `UsersService`. It is possible that there are other ways of implementing these methods and you should feel free to implement them as you see fit.

## Server Setup

### routes.go Setup

Now that we have a user service that can interact with the database layer, we can set up our gin server. We will again start by defining some interfaces which will be used by our application.

In the `routes.go` file we will first define an `Application` interface with a single method:

```
type Application interface {
	Run() error
}
```

Next, we will define a `userService` interface for the user service we just created:

```
type userService interface {
	GetUsers(name string) ([]service.User, error)
	GetUserByID(id uint64) (service.User, error)
	CreateUser(user *service.User) (service.User, error)
	UpdateUser(id uint64, user *service.User) error
	DeleteUser(id uint64) error
}
```

Finally, we will create a `BlogApplication` struct as a wrapper for the `userService` (and eventually all of the other services) along with a helper method to build a new `BlogApplication`:

```
type BlogApplication struct {
	userService userService
}

func NewBlogApplication(userService userService) BlogApplication {
	return BlogApplication{userService: userService}
}
```

### user.go Setup

Now, move over to the `internal/routes/user.go` file. In here, we will implement the various handler functions that the gin engine will eventually use. Start by defining the a couple of the errors our API will return:

```
var (
	internalError   = ErrorResponse{ErrorId: 1000, Message: "Internal service error"}
	userNotFound    = ErrorResponse{ErrorId: 1001, Message: "Error: user not found"}
)
```

Next, take this function `getUserByID`:

```
func getUserByID(s userService) func(c *gin.Context) {
	return func(c *gin.Context) {
		uid, err := validateID(c.Param("id"))
		if err != nil {
			c.JSON(http.StatusBadRequest, invalidIDError)
			return
		}
		user, err := s.GetUserByID(uid)
		if err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				c.JSON(http.StatusNotFound, userNotFound)
			} else {
				c.JSON(http.StatusInternalServerError, internalError)
			}
			return
		}
		c.JSON(http.StatusOK, userResponse{User: &user})
	}
}
```

Now implement similar functions for the following method signatures:

```
func getUsers(s userService) func(c *gin.Context)
func createUser(s userService) func(c *gin.Context)
func updateUser(s userService) func(c *gin.Context)
func deleteUser(s userService) func(c *gin.Context)
```

### Gin Engine Setup

Now that we have our handler functions set up, navigate back to `routes.go`. We can now implement the `newEngine` method that will build a gin engine and set up the routing:

```
// newEngine builds a new Gin router and configures the routes to be handled.
func newEngine(a *BlogApplication) *gin.Engine {
	router := gin.Default()

	api := router.Group("/api")
	api.GET("/health", health)

	user := api.Group("/user")
	{
		user.GET("/", getUsers(a.userService))
		user.GET("/:id", getUserByID(a.userService))
		user.POST("/", createUser(a.userService))
		user.PUT("/:id", updateUser(a.userService))
		user.DELETE("/:id", deleteUser(a.userService))
	}

	return router
}
```

We can also implement a `Run()` method on the `*BlogApplication` so that it implements the `Application` interface:

```
func (a *BlogApplication) Run() error {
	engine := newEngine(a)
	return engine.Run()
}
```

Now that we have our gin engine set up, lets walk through generating our swagger documentation for our endpoints.

### Generating Swagger Docs

To add swagger to our application, ensure that you have already installed swaggo to the project using the command below in your terminal:

```
go install github.com/swaggo/swag/cmd/swag@latest
```

Next, we will need to provide swagger basic information to help generate our swagger documentation. Above the `Run()` method, add the following comments:

```
//	@title			Blog Service API
//	@version		1.0
//	@description	Practice Go Gin API using GORM and Postgres
//	@termsOfService	http://swagger.io/terms/
//	@contact.name	API Support
//	@contact.url	http://www.swagger.io/support
//	@contact.email	support@swagger.io
//	@license.name	Apache 2.0
//	@license.url	http://www.apache.org/licenses/LICENSE-2.0.html
//	@host		localhost:8080
//	@BasePath	/api
// @externalDocs.description	OpenAPI
// @externalDocs.url			https://swagger.io/resources/open-api/
```

For more detailed description on what each annotation does, please see [Swaggo's Declarative Comments Format](https://github.com/swaggo/swag?tab=readme-ov-file#declarative-comments-format)

Next, we will add swagger comments for each of our endpoints. Head over to `internal/routes/user.go`. Above the `getUserByID` function, add the following comments:

```
// @Summary		Fetch User
// @Description	Fetch User by ID
// @Tags			user
// @Accept			json
// @Produce		json
// @Param			id	path		string	true	"User ID"
// @Success		200	{object}	routes.userResponse
// @Failure		400	{object}	routes.ErrorResponse
// @Failure		404	{object}	routes.ErrorResponse
// @Failure		500	{object}	routes.ErrorResponse
// @Router			/user/{id} [GET]
```

The above comments help identify to swagger important information like the path of the endpoint, any parameters or request bodies, and response types and objects. For more information about each annotation and additional annotations you will need, see [Swaggo Api Operation](https://github.com/swaggo/swag?tab=readme-ov-file#api-operation).

Now add the proper swagger comments for the following method signatures:

```
func getUsers(s userService) func(c *gin.Context)
func createUser(s userService) func(c *gin.Context)
func updateUser(s userService) func(c *gin.Context)
func deleteUser(s userService) func(c *gin.Context)
```

You are almost there! We can now attach swagger to our project and generate the documentation based off our comments. In the `newEngine` function, add the following line right below `router := gin.Default()`:

```
router.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))
```

> **Note:** You will also need to add the following imports at the top of the file
>
> ```
> swaggerFiles "github.com/swaggo/files"
> ginSwagger "github.com/swaggo/gin-swagger"
> ```
>
> Next, generate the swagger documentation by running the following make command:

```
make swag-init
```

If successful, this should generate the swagger documentation for the project and place it in `cmd/api/docs`.

> **Important:** The documentation that was just created may contain an error at the end of the file which will need to be handled before starting the application. To fix this, proceed over to the newly generated `cmd/api/docs/docs.go` file and remove the following two lines at the end of the project:
>
> ```
> LeftDelim:        "{{",
> RightDelim:       "}}",
> ```
>
> This issue appears to occur every time you generate the swagger documentation, and will be something to note as you continue working through the tech challenge
> Finally, proceed over to `cmd/api/main.go` and add the following to your list of imports. Remember to replace `[name]` with your name:

```
_ "github.com/[name]/blog/cmd/api/docs"
```

Congrats! You have now generated the swagger documentation for our application! We can now start up our application and hit our endpoints!

### main.go Setup and Running Application

We now have enough code to run the API end-to-end! Navigate to `main.go` In the `main` function, comment out or remove any code leftover from the initial setup. In the `main` function, we will first start by loading the config we set up earlier:

```
config, err := c.LoadConfig(".")
	if err != nil {
		log.Fatal("error loading configuration", err)
	}
```

Next, create a connection to the database. Note that once they have been built out, all services in the API will use this same DB connection:

```
db, err := database.ConnectDb(
	postgres.Open(
		fmt.Sprintf(
			"host=%s user=%s password=%s dbname=%s port=%s sslmode=disable TimeZone=Asia/Shanghai",
			config.DBHost,
			config.DBUserName,
			config.DBUserPassword,
			config.DBName,
			config.DBPort,
		),
	),
	&gorm.Config{},
)
if err != nil {
	log.Fatal("error connecting to database", err)
}
fmt.Println("Connected successfully to the database")
```

Finally, we will set up the `UserService`, `BlogApplication`, and run the app:

```
us := service.NewUserService(db)

app := routes.NewBlogApplication(us)

log.Fatal(app.Run())
```

At this point, you should be able to run your appliacation. You can do this using the make command `make start-web-app` or using basic go build and run commands. If you encounter issues, ensure that your database container is running in podman, and that there are no syntax errors present in the code.

## Unit Testing

### Unit Testing Introduction

It is important with any language to test your code. Go make it easy to write unit tests, with a robust built-in testing framework. For a brief introduction on unit testing in Go, check out [this YouTube video](https://www.youtube.com/watch?v=FjkSJ1iXKpg).

### Unit Testing in This Tech Challenge

Unit testing is a required part of this tech challenge. There are not specific requirements for exactly how you must write your unit tests, but keep the following in mind as you go through the challenge:

- Go prefers to use table-driven, parallel unit tests. For more information on this, check out the [Go Wiki](https://go.dev/wiki/TableDrivenTests).
- Try to write your code in a way that is, among other things, easy to test. Go's preference for interfaces facilitates this nicely, and it can make your life easier when writing tests.
- There are already make targets set up to run unit tests. Specifically `check-coverage`. Feel free to modify these and add more if you would like to tailor them to your own preferences.

## Next Steps

You are now ready to move on to the rest of the challenge. You can find the instructions for that [here](./3-Challenge-Assignment.md).
