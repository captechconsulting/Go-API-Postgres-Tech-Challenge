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

As previously mentioned, this challenge is centered around the use of Gin, a very popular web framework for Go. Gin enables you to easily create web servers with full control of routing, validation and much more. For more information on Gin, check out [this Gin overview](https://gin-gonic.com/docs/introduction/) or the [Gin package docs](https://pkg.go.dev/github.com/gin-gonic/gin).The Gin web server will connect to a PostgreSQL database in the backend. This walkthrough will consist of a step-by-step guide for creating the REST API for the `users` table in the database. By the end of the walkthrough, you will have endpoints capable of creating, reading, updating, and deleting from the `users` table.

## Project Structure

By default, you should see the following file structure in your root directory
```
cmd/
  http/
    routes/
    main.go
internal/
  config/
  database/
  service/
Makefile
```

Before beginning to look through the project structure, ensure that you first understand the basics of Go project structuring. As a good starting place, check out [Organizing a Go Module](https://go.dev/doc/modules/layout) from the Go team, or check out [this Markdown file](https://gist.github.com/ayoubzulfiqar/9f1a34049332711fddd4d4b2bfd46096) with a common structure. It is important to note, that one size does not fit all Go projects. It may make more sense to vary from these common structures, depending on the work you are doing.


The `cmd/` folder contains the entrypoint(s) for the application. For this Tech Challenge, we will only need one entrypoint into the application, `http`. However, as an extension, you could implement more entrypoints.

The `cmd/http` folder contains the entrypoint code specific to setting up a webserver for our application. This includes the handler functions for the various endpoints.

The `internal/` folder contains internal packages that comprise the bulk of the application logic for the challenge:
- The `config` package contains utilities for configuring the database
- The `database` package contains logic for connecting to and hydrating the database, interacting with the database, and models for the various entities we will be working with
- The `service` package is responsible for the main application logic that will be called by the handlers, and will utilize the `database` package

The `Makefile` contains various `make` commands that will be helpful throughout the project. We will reference these as they are needed. Feel free to look through the `Makefile` to get an idea for what's there or add your own make targets.

Now that you are familiar with the current structure of the project, we can begin connecting our application to our database.

## Database Setup

We will first begin by setting up the database layer of our application.

### Configure the Connection to the Database

In order for the project to be able to connect to the PostgreSQL database, you will need to handle the configuration.

First, create an `app.env` file to contain the credentials required for the Postgres image.
```
POSTGRES_HOST=127.0.0.1
POSTGRES_USER=user
POSTGRES_PASSWORD=goChallenge
POSTGRES_DB=blogs
POSTGRES_PORT=5432

PORT=8000
CLIENT_ORIGIN=http://localhost:3000
```

### Load and Validate the Environment Variables
To handle loading the environment variables into the application, we will be utilizing the `viper` package. If you have not already done so, download the `viper` package by running the following command in your terminal.
```
go get github.com/spf13/viper
```

Now, find the `internal/config/config.go` file that will be responsible for storing the structs to contain the allowed environment variables. Add in the following struct: 
```
type Config struct {
	DBHost         string `mapstructure:"POSTGRES_HOST"`
	DBUserName     string `mapstructure:"POSTGRES_USER"`
	DBUserPassword string `mapstructure:"POSTGRES_PASSWORD"`
	DBName         string `mapstructure:"POSTGRES_DB"`
	DBPort         string `mapstructure:"POSTGRES_PORT"`
	ServerPort     string `mapstructure:"PORT"`

	ClientOrigin string `mapstructure:"CLIENT_ORIGIN"`
}
```

Now, add the following function to the `internal/config/config.go` file:
```
func LoadConfig(path string) (*Config, error) {
   var config Config
   viper.AddConfigPath(path)
   viper.SetConfigType("env")
   viper.SetConfigName("app")
   
   viper.AutomaticEnv()

   err := viper.ReadInConfig()
   if err != nil {
       return &config, err
   }

   err = viper.Unmarshal(&config)
   return &config, err
}
```
In the above code, we created a function called `LoadConfig()` responsible for loading the environment variables from the `app.env` file and make them accessible in other files and packages within the application code.

### Make a Utility Function to Connect to PostgreSQL

Next, we will write a helper function to connect to the PostgreSQL server from the application. To do that, we will be utilizing the `gorm` package and the underlying `postgres` driver from GORM. We will wrap this connection in a `Database` struct so that one connection can be passed around the program. First, download the `gorm` package: 
```
go get -u gorm.io/gorm  
```

Then, in the `internal/database/database.go` file, add the function and struct below:
```
type Database struct {
	DB *gorm.DB
}

func ConnectDb(d gorm.Dialector, c *gorm.Config) (Database, error) {
	db, err := gorm.Open(d, c)
	if err != nil {
		return Database{}, fmt.Errorf("error opening database: %w", err)
	}
	return Database{DB: db}, nil
}
```
We will use this `ConnectDb()` helper function in our `main.go` file to create a new connection with the database upon start-up.


### Test the Connection to the Database

You can now connect the application to the database. Add the following lines to that main function in your `cmd/http/main.go` file so it looks like below:
```
config, err := c.LoadConfig(".")
	if err != nil {
		log.Fatal("error loading configuration", err)
	}
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
	// db, err := database.ConnectDB(config.DBHost, config.DBUserName, config.DBUserPassword, config.DBName, config.DBPort)
	if err != nil {
		log.Fatal("error connecting to database", err)
	}
	fmt.Println("Connected successfully to the database")
```
\* Note you may need to install the `gorm.io/driver/postgres` package

At this point, you can now test to see if you application is able to successfully connect to the Postgres database. To do so, open a terminal in the project root directory and run the command `go run main.go`. You should see the following output:
```
Connected Successfully to the database
```

Congrats! You have managed to connect to your Postgres database from your application. 

If your application is unable to connect to the database, ensure that the podman container for the database is running. Additionally, verify that the environment variables set up in previous steps are being loaded correctly.

### Setting up User Model

Now that we have been able to successfully able to connect to the database, we will set up some basic database utilities for the users in our application.

Create an `entites.go` file in the `database` package. This file will be used to hold the models for the structs that will be mapped to the objects in the database. Add the following struct: 

```
type User struct {
	ID       uint   `json:"id"`
	Name     string `json:"name"`
	Email    string `json:"email"`
	Password string `json:"password"`
}
```

### Setting up User Utilities

Next, create a file called `user.go` in the `database` package. This file will house the functionality for creating, reading, updating and deleting users in the database.

We will first be creating a `GetUserByID` method on the `Database` struct to retrieve a user from the database with a given ID called `GetUserByID`.

Here is an implementation of `GetUserByID` that you can use:

```
func (database Database) GetUserByID(id uint64) (*User, error) {
	var user User
	result := database.DB.First(&user, id)
	if result.Error != nil {
		return nil, fmt.Errorf("error getting user: %w", result.Error)
	}

	return &user, nil
}
```

Let's quickly walk through the structure of this function, as it will serve as a sort of template for other similar methods:
- First, a User var is created, which will hold the information of the user we search for
- Next, the information of the user is retrieved using the `First` method on our database connection. For documentation on this and other similar methods, see the Gorm docs [here](https://gorm.io/docs/query.html). Note that we pass a pointer for the `user` var we declared so that the information can be bound to the object.
- Next, we check if there was an error retrieving the information, and if there was, we wrap the error and return it
- If there was no error, we return a pointer to `user`, which contains the user information

Now, go through an implement similar methods with the following method signatures:

```
func (database Database) GetUsers(name string) ([]User, error)
func (database Database) CreateUser(user *User) (*User, error)
func (database Database) UpdateUser(id uint64, user *User)
func (database Database) DeleteUser(id uint64) error
```

These methods should leverage the `Where`, `First`, `Create`, `Model`, `Updates`, and `Delete` methods on the `DB` object on `database`. It is possible that there are other ways of implementing these methods and you should feel free to implement them as you see fit.

## Service Setup

Now that the database layer of our application is set up, we will set up the web server layer

### Defining Models
We will now set up a user service in the `service` package 

We will first define a few structs that will be referenced later on. Begin by defining a User struct, similar to how we did in the `database` package:

```
type User struct {
	ID       uint   `json:"id"`
	Name     string `json:"name"`
	Email    string `json:"email"`
	Password string `json:"password"`
}
```

This may seem redundant, since this model contains nearly the same information as the model in the `database` package did. There are many approaches to defining models like this in go. Some projects opt for defining models in a centralized `models` package, to be reused in different places throughout the program. Others define models in the packages or bounded contexts where they are used. There is no one-size-fits-all approach. It is important to come up with a design that balances separation of concerns, ease of use, minimizing boilerplate and any other concerns related to data modeling. For this project, we will define separate models in the various layers of the application and translate between them as necessary.

Next define a `databaseSession` interface as follows:

```
type databaseSession interface {
	GetUsers(name string) ([]database.User, error)
	GetUserByID(id uint64) (*database.User, error)
	CreateUser(user *database.User) (*database.User, error)
	UpdateUser(id uint64, user *database.User) error
	DeleteUser(id uint64) error
}
```

Notice the parallels between the methods in the `databaseSession` interface and the methods we defined on the `database` in the previous section.

We can now define a `UserService` struct as well as a function `NewUserService` for creating a new `UserService`:

```
type UserService struct {
	Database databaseSession
}

func NewUserService(db databaseSession) UserService {
	return UserService{Database: db}
}
```

We have now defined an object (`UserService`) which will ultimately take in the `database` object that we implemented in the previous section in order to interact with the database.

### Implementing UserService Methods

Next we will define the methods on the `UserService`. We will start by creating a `GetUserByID` method that takes in an ID and retrieves that user from the database. Before we do this, however, we will make a helper function to translate between the user model defined in the `service` package and the user model defined in the `database` package. This can be done with the following:

```
func userFromDBUser(dbUser *database.User) User {
	return User{
		ID:       dbUser.ID,
		Name:     dbUser.Name,
		Email:    dbUser.Email,
		Password: dbUser.Password,
	}
}
```

It will also be helpful to define a similar function that translate a `service.User` to a `database.User`

With this helper function, we can now implement the GetUserByID function:

```
func (s UserService) GetUserByID(id uint64) (User, error) {
	user, err := s.Database.GetUserByID(id)
	if err != nil {
		return User{}, fmt.Errorf("in UserService.GetUserByID: %w", err)
	}
	return userFromDBUser(user), nil
}
```

Now, go through and implement methods for the following function signatures, similarly to how `GetUserByID` was implemented:

```
func (s UserService) GetUsers(name string) ([]User, error)
func (s UserService) CreateUser(user *User) (User, error)
func (s UserService) UpdateUser(id uint64, user *User) error
func (s UserService) DeleteUser(id uint64) error
```

All of these methods should look similar to the following steps:
- Leverage a method on `s.Database` to interact with the database
- Check for errors from the call in the first step
- Translate the data into the correct form and return

## Server Setup

### routes.go Setup

Now that we have a user service that can interact with the database layer, we can set up our gin server. We will again start by defining some interfaces which will be used by our application. 

In the `routes.go` file we will first  define an `Application` interface with a single method:

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

Now, move over to the `cmd/http/routes/user.go` file. In here, we will implement the various handler functions that the gin engine will eventually use. Start by defining the a couple of the errors our API will return:

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

Next, we will add swagger comments for each of our endpoints. Head over to `cmd/http/routes/user.go`. Above the `getUserByID` function, add the following comments:

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
Next, generate the swagger documentation by running the following make command:

```
make swag-init
```

If successful, this should generate the swagger documentation for the project and place it in `cmd/http/docs`.

> **Important:** The documentation that was just created may contain an error at the end of the file which will need to be handled before starting the application. To fix this, proceed over to the newly generated `cmd/http/docs/docs.go` file and remove the following two lines at the end of the project:
> ```
> LeftDelim:        "{{",
> RightDelim:       "}}",
> ```
> This issue appears to occur every time you generate the swagger documentation, and will be something to note as you continue working through the tech challenge
Finally, proceed over to `cmd/http/main.go` and add the following to your list of imports. Remember to replace `[name]` with your name:

```
_ "github.com/[name]/blog/cmd/http/docs"
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