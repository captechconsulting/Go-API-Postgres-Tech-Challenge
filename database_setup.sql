DROP TABLE IF EXISTS "users";
DROP TABLE IF EXISTS blogs;
DROP TABLE IF EXISTS "comments";

-- Create user table
CREATE TABLE "users" (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    password TEXT NOT NULL
);

-- Create blog table
CREATE TABLE "blogs" (
    id BIGSERIAL PRIMARY KEY,
    author_id INTEGER NOT NULL,
    title TEXT NOT NULL,
    score REAL NOT NULL,
    created_date TIMESTAMP NOT NULL
);

-- Create comment table
CREATE TABLE "comments" (
    user_id BIGSERIAL NOT NULL,
    blog_id BIGSERIAL NOT NULL,
    message TEXT NOT NULL,
    created_date TIMESTAMP NOT NULL,
    PRIMARY KEY (user_id, blog_id)
);

-- Insert data into the user table
INSERT INTO "users" (name, email, password) VALUES
    ('John Doe', 'john@example.com', 'password1'),
    ('Jane Smith', 'jane@example.com', 'password2'),
    ('Alice Johnson', 'alice@example.com', 'password3'),
    ('Bob Brown', 'bob@example.com', 'password4'),
    ('Emma Davis', 'emma@example.com', 'password5'),
    ('Michael Wilson', 'michael@example.com', 'password6'),
    ('Sarah Lee', 'sarah@example.com', 'password7'),
    ('David Garcia', 'david@example.com', 'password8'),
    ('Olivia Martinez', 'olivia@example.com', 'password9'),
    ('William Rodriguez', 'william@example.com', 'password10');

-- Insert data into the blog table
INSERT INTO blogs (author_id, title, score, created_date) VALUES
    (1, 'First Blog Post', 8.5, '2024-05-14 09:00:00'),
    (2, 'Travel Adventures', 7.2, '2024-05-13 14:30:00'),
    (3, 'Cooking Tips', 9.3, '2024-05-12 11:45:00'),
    (4, 'Tech Reviews', 6.7, '2024-05-11 16:20:00'),
    (5, 'Fitness Journey', 8.9, '2024-05-10 08:15:00'),
    (6, 'Book Recommendations', 7.8, '2024-05-09 10:45:00'),
    (7, 'Photography Tips', 9.1, '2024-05-08 13:20:00'),
    (8, 'Financial Advice', 6.4, '2024-05-07 17:30:00'),
    (9, 'DIY Projects', 8.0, '2024-05-06 09:45:00'),
    (10, 'Movie Reviews', 7.5, '2024-05-05 14:00:00'),
    (1, 'Second Blog Post', 8.2, '2024-05-04 11:10:00'),
    (2, 'Healthy Recipes', 9.0, '2024-05-03 15:25:00'),
    (3, 'Productivity Hacks', 8.7, '2024-05-02 10:50:00'),
    (4, 'Gaming News', 7.3, '2024-05-01 12:15:00'),
    (5, 'Home Decor Ideas', 9.5, '2024-04-30 09:30:00');

-- Insert data into the comment table
INSERT INTO "comments" (user_id, blog_id, message, created_date) VALUES
    (1, 8, 'Saving money has never been easier with these tips!', '2024-05-15 12:00:00'),
    (2, 11, 'I agree with your points.', '2024-05-15 12:15:00'),
    (2, 4, 'Exciting developments in the tech world.', '2024-05-15 12:15:00'),
    (4, 5, 'Sweat is just fat crying.', '2024-05-15 12:45:00'),
    (5, 3, 'Perfect for a cozy night in.', '2024-05-15 13:00:00'),
    (1, 2, 'What a beautiful destination!', '2024-05-15 12:00:00'),
    (1, 5, 'Feeling the burn!', '2024-05-15 12:00:00'),
    (1, 1, 'Great post!', '2024-05-15 12:00:00'),
    (1, 3, 'This recipe looks delicious!', '2024-05-15 12:00:00'),
    (5, 10, 'I laughed, I cried, I loved it.', '2024-05-15 13:00:00'),
    (2, 9, 'Getting crafty with this idea.', '2024-05-15 12:15:00'),
    (2, 2, 'I wish I could visit there someday.', '2024-05-15 12:15:00'),
    (1, 14, 'Exciting news in the gaming world!', '2024-05-15 12:00:00'),
    (1, 13, 'These productivity tips are game-changers!', '2024-05-15 12:00:00'),
    (6, 1, 'Interesting perspective.', '2024-05-15 13:15:00'),
    (2, 7, 'Improving my photography skills one tip at a time.', '2024-05-15 12:15:00'),
    (2, 6, 'Love the recommendation!', '2024-05-15 12:15:00'),
    (2, 15, 'Can''t wait to redecorate my space.', '2024-05-15 12:15:00'),
    (4, 10, 'A must-watch for any movie buff.', '2024-05-15 12:45:00'),
    (2, 3, 'Can''t wait to try this at home.', '2024-05-15 12:15:00'),
    (1, 10, 'This movie was amazing!', '2024-05-15 12:00:00'),
    (3, 11, 'This made me think.', '2024-05-15 12:30:00'),
    (7, 12, 'Any suggestions for substitutions?', '2024-05-15 13:30:00'),
    (9, 15, 'Home decor is my passion.', '2024-05-15 14:00:00'),
    (3, 7, 'Can''t wait to try this technique.', '2024-05-15 12:30:00'),
    (10, 7, 'Ready to capture the world.', '2024-05-15 14:15:00'),
    (4, 14, 'The graphics in this trailer look amazing.', '2024-05-15 12:45:00'),
    (4, 1, 'Thanks for sharing.', '2024-05-15 12:45:00'),
    (3, 8, 'Planning for the future with smart investments.', '2024-05-15 12:30:00'),
    (1, 12, 'This recipe looks delicious and healthy!', '2024-05-15 12:00:00'),
    (7, 7, 'Any tips for shooting in low light?', '2024-05-15 13:30:00'),
    (5, 15, 'Creating a cozy atmosphere with these tips.', '2024-05-15 13:00:00'),
    (1, 4, 'This new technology is groundbreaking!', '2024-05-15 12:00:00'),
    (1, 7, 'Captured a beautiful moment thanks to this tip!', '2024-05-15 12:00:00'),
    (4, 6, 'Excited to dive into this story.', '2024-05-15 12:45:00'),
    (4, 15, 'Adding these decor ideas to my Pinterest board.', '2024-05-15 12:45:00'),
    (2, 5, 'Pushing past my limits.', '2024-05-15 12:15:00'),
    (1, 6, 'Adding this to my reading list!', '2024-05-15 12:00:00'),
    (3, 1, 'Insightful!', '2024-05-15 12:30:00'),
    (2, 14, 'Can''t wait for this game to be released!', '2024-05-15 12:15:00'),
    (6, 14, 'Hyped for the upcoming esports tournament.', '2024-05-15 13:15:00'),
    (5, 13, 'Feeling more focused and motivated already.', '2024-05-15 13:00:00'),
    (3, 15, 'This room makeover is goals!', '2024-05-15 12:30:00'),
    (10, 8, 'Ready to build wealth and achieve my goals.', '2024-05-15 14:15:00'),
    (7, 5, 'Taking my fitness journey one step at a time.', '2024-05-15 13:30:00'),
    (6, 11, 'Can you elaborate more?', '2024-05-15 13:15:00'),
    (7, 9, 'Any tips for beginners?', '2024-05-15 13:30:00'),
    (2, 12, 'Can''t wait to try this nutritious dish!', '2024-05-15 12:15:00'),
    (10, 10, '10/10 would watch again.', '2024-05-15 14:15:00'),
    (9, 14, 'Ready to level up!', '2024-05-15 14:00:00'),
    (6, 5, 'No pain, no gain!', '2024-05-15 13:15:00');