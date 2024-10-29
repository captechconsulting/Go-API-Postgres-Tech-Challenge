DROP TABLE IF EXISTS person_course;
DROP TABLE IF EXISTS course;
DROP TABLE IF EXISTS person;

-- person
CREATE TABLE person
(
    id         SERIAL PRIMARY KEY,
    first_name TEXT                                          NOT NULL,
    last_name  TEXT                                          NOT NULL,
    type       TEXT CHECK (type IN ('professor', 'student')) NOT NULL,
    age        INTEGER                                       NOT NULL
);

INSERT INTO person (first_name, last_name, type, age)
VALUES ('Steve', 'Jobs', 'professor', 56),
       ('Jeff', 'Bezos', 'professor', 60),
       ('Larry', 'Page', 'student', 51),
       ('Bill', 'Gates', 'student', 67),
       ('Elon', 'Musk', 'student', 52);

-- course
CREATE TABLE course
(
    id   SERIAL PRIMARY KEY,
    name TEXT NOT NULL
);

INSERT INTO course (name)
VALUES ('Programming'),
       ('Databases'),
       ('UI Design');

-- person_course
CREATE TABLE person_course
(
    person_id INTEGER NOT NULL,
    course_id INTEGER NOT NULL,
    PRIMARY KEY (person_id, course_id),
    FOREIGN KEY (person_id) REFERENCES person (id),
    FOREIGN KEY (course_id) REFERENCES course (id)
);

INSERT INTO person_course (person_id, course_id)
VALUES (1, 1),
       (1, 2),
       (1, 3),
       (2, 1),
       (2, 2),
       (2, 3),
       (3, 1),
       (3, 2),
       (3, 3),
       (4, 1),
       (4, 2),
       (4, 3),
       (5, 1),
       (5, 2),
       (5, 3);