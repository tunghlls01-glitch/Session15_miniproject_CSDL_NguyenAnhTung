create database Session15_miniproject;
use Session15_miniproject;

-- tạo bảng người dùng 
create table users(
	user_id int primary key auto_increment,
    username varchar(50) unique not null,
    password varchar(255) not null,
    email varchar(100) unique not null,
    created_at datetime default current_timestamp
);
-- bảng bài viết
create table posts (
	post_id int primary key auto_increment,
    user_id int,
    content text not null,
    like_count int default 0, -- tổng like
    comment_count int default 0, -- tổng bình luận
    created_at datetime	default current_timestamp,
    foreign key (user_id) references users(user_id)
);
-- bảng bình luận
create table comments (
	comment_id int primary key auto_increment,
    post_id int,
    user_id int,
    content text not null,
    created_at datetime	default current_timestamp,
    foreign key (post_id) references posts(post_id) on delete cascade,
    foreign key (user_id) references users(user_id)
);
-- bảng bạn bè 
create table friends (
	friendship_id int primary key auto_increment,
    user_id int,
    friend_id int,
    status varchar(20) check (status in ('pending', 'accepted')),
    created_at datetime	default current_timestamp,
    foreign key (user_id) references users(user_id),
    foreign key (friend_id) references users(user_id),
    CHECK (user_id != friend_id)
);
-- bảng thích 
create table likes (
	like_id int primary key auto_increment,
    post_id int,
    user_id int,
    created_at datetime	default current_timestamp,
    foreign key (post_id) references posts(post_id) on delete cascade,
    foreign key (user_id) references users(user_id),
    UNIQUE(user_id, post_id)
);
-- tạo dữ liệu
INSERT INTO users (username, password, email) VALUES
('an', '123456', 'an@gmail.com'),
('binh', '123456', 'binh@gmail.com'),
('chi', '123456', 'chi@gmail.com'),
('dung', '123456', 'dung@gmail.com'),
('em', '123456', 'em@gmail.com');

INSERT INTO posts (user_id, content) VALUES
(1, 'Hôm nay học SQL khá vui'),
(1, 'MySQL Stored Procedure rất hay'),
(2, 'Đi cafe với bạn bè'),
(3, 'Chạy project mini social network'),
(4, 'Học database thật thú vị');

INSERT INTO comments (post_id, user_id, content) VALUES
(1, 2, 'Chuẩn luôn!'),
(1, 3, 'Mình cũng đang học SQL'),
(2, 4, 'Procedure hơi khó nhưng hay'),
(3, 1, 'Chúc bạn hoàn thành tốt'),
(5, 2, 'Database rất quan trọng');

INSERT INTO friends (user_id, friend_id, status) VALUES
(1, 2, 'accepted'),
(1, 3, 'pending'),
(2, 3, 'accepted'),
(2, 4, 'pending'),
(3, 5, 'accepted'),
(4, 1, 'pending');

INSERT INTO likes (post_id, user_id) VALUES
(1, 2),
(1, 3),
(1, 4),
(2, 3),
(2, 5),
(3, 1),
(3, 2),
(4, 5),
(5, 1);

-- F01 Đăng ký thành viên : Tạo tài khoản mới, kiểm tra trùng lặp thông tin, mã hóa mật khẩu.
DELIMITER $$
create procedure create_account (in username_in varchar(50), in password_in varchar(255), in email_in varchar(100), OUT message text)
begin
	-- biến lưu 
	declare save_username int;
    declare save_email int;
    -- lấy tên trùng
    select count(*) into save_username
    from users 
    where username = username_in;
    -- lấy email trung
    select count(*) into save_email
    from users 
    where email = email_in;
    -- check trùng
    if save_username > 0 then 
		set message = 'tên đã tồn tại';
	elseif save_email > 0 then 
		set message = 'email đã tồn tại';
	else
	insert into users (username, password, email)
    values 
    (username_in, sha2(password_in, 256), email_in);
		set message = 'thêm tài khoản thành công';
    end if;
end $$
DELIMITER ;

-- F02: đăng bài (người dùng tạo bài viết mới)
DELIMITER $$
create procedure create_post (in user_id_in int, in content_in text, out message text)
begin
	declare save_user int;
	declare save_count int;
	-- tìm có user không 
    select count(*) into save_user
    from users
    where user_id = user_id_in;
    -- trùng content
    select count(*) into save_count
    from posts
    where user_id = user_id_in and content = content_in;
    -- check
    if save_user = 0 then
		set message = 'tài khoản không tồn tại';
	elseif save_count > 0 then
		set message = 'đã có bài viết này';
	else
	-- thêm bài đăng
	insert into posts (user_id, content)
    values 
    (user_id_in, content_in);
    set message = 'đăng bài thành công';
    end if;
end $$
DELIMITER ;

-- F03: thich/ huy thich bai viết 
-- tăng like 
DELIMITER $$
CREATE TRIGGER Like_this_post
after insert 
on likes
for each row
begin
	update posts
    set  like_count = like_count + 1
    WHERE post_id = NEW.post_id;
end $$
DELIMITER ;
-- giảm like 
DELIMITER $$
create trigger un_Like_this_post
after delete 
on likes
for each row
begin
	update posts
    set  like_count = like_count - 1
    WHERE post_id = OLD.post_id;
end $$
DELIMITER ;
-- F04 : Gửi lời mời kết bạn (Gửi lời mời kết bạn cho người dùng khác. Có cơ chế chặn gửi trùng lặp đảo chiều).
DELIMITER $$
create trigger make_friend
before insert 
on friends
for each row
begin
	 declare save_friend int;
     -- kiểm tra tồn tại chưa 
     select count(*) into save_friend
     from friends 
     where user_id = new.friend_id 
     and friend_id = new.user_id;
     if save_friend > 0 then
		signal sqlstate '45000' set message_text = 'Đã tồn tại lời mời kết bạn';
     end if;
     
end $$
DELIMITER ;

-- F05: Chấp nhận/Hủy kết bạn (Cập nhật trạng thái status hoặc xóa bản ghi nếu hủy lời mời.)
DELIMITER $$
create procedure accept_friend (in friendship_id_in int, out message text)
begin
	declare save_friend int;
    -- kiểm tra tồn tại lời mời này chưa
    select count(*) into save_friend 
    from friends
    where friendship_id = friendship_id_in;
    -- xử lý 
    if save_friend = 0 then 
		set message = 'Lời mời kết bạn không tồn tại';
	else 
		update friends
        set status = 'accepted'
        where friendship_id = friendship_id_in;
        set message = 'kết bạn thành công';
	end if;
end $$
DELIMITER ;
-- xóa kết bạn
DELIMITER $$
create procedure reject_friend (in friendship_id_in int, out message text)
begin
	declare save_friend int;
    -- kiểm tra tồn tại lời mời này chưa
    select count(*) into save_friend 
    from friends
    where friendship_id = friendship_id_in;
    -- xử lý 
    if save_friend = 0 then 
		set message = 'Lời mời kết bạn không tồn tại';
	else 
		DELETE FROM friends
        WHERE friendship_id = friendship_id_in;
        set message = 'không chấp nhận kết bạn';
	end if;
end $$
DELIMITER ;
-- f06: Xem thông tin người dùng (Xem trang cá nhân của người dùng.)
create view view_user_profile as
select u.user_id, u.username, u.email, u.created_at, count(p.post_id) as total_posts
from users u 
join posts p
on u.user_id = p.user_id
group by u.user_id, u.username, u.email, u.created_at;
-- f07: Xem bài viết theo từ khóa (Tìm kiếm bài viết theo nội dung content.)
ALTER TABLE posts
ADD FULLTEXT(content);
DELIMITER $$
create procedure search_post (in keywork varchar(225))
begin
	select post_id,user_id,content,like_count,comment_count,created_at
    from posts 
    where match(content) against (keywork);
end $$
DELIMITER ;
-- f08: báo cáo hoạt động 
DELIMITER $$
create procedure report_article (in user_id_in varchar(5), out message text)
begin
	declare save_user_id int;
    select count(*) into save_user_id
    from users 
    where user_id = user_id_in;
    if save_user_id = 0 then 
		set message = 'không có tai khoan này';
	else 
        select u.user_id, u.username, count(p.post_id) as total_posts, sum(p.like_count) as total_like, sum(p.comment_count) as total_comment
		from users u 
		LEFT join posts p
		on u.user_id = p.user_id
        where u.user_id = user_id_in
		group by u.user_id, u.username;
        set message = 'Hiển thị báo cáo thành công';
    end if;
end $$
DELIMITER ;

-- F09: Gợi ý kết bạn (Hệ thống gợi ý bạn bè (Mutual friends / Bạn của bạn).)
DELIMITER $$
create procedure suggest_friend (in user_id_in INT)
begin
	select distinct u.user_id, u.username
    from users u
    join friends f1
    on u.user_id = f1.friend_id
    where f1.user_id in (	
		-- danh sách bạn hiện tại
        select friend_id
        from friends
        where user_id = user_id_in
        and status = 'accepted'
    ) 
    -- không gợi ý bạn chính mình
    and u.user_id <> user_id_in 
    -- loại đã lf bạn
    and u.user_id not in (
		select friend_id
        from friends
        where user_id = user_id_in
        AND status = 'accepted'
    );
end $$
DELIMITER ;
-- f10: xóa bai viết (Người dùng xóa bài viết của chính mình. Dữ liệu liên quan (likes, comments) được dọn dẹp bằng Cascade hoặc Transaction.)
DELIMITER $$
create procedure delete_post (in post_id_in varchar(5), in user_id_in varchar(5), out message text)
begin
	declare save_post_id int;
    -- kiểm tra lỗi 
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET message = 'Xóa bài viết thất bại';
    END;
    -- tìm bài viết tồn tại
    select count(*) into save_post_id
    from posts 
    where post_id = post_id_in and user_id = user_id_in;
    if save_post_id = 0 then
		set message = 'không có bài viết';
	else
		start transaction;
        delete 
        from posts
        where post_id = post_id_in;
        commit;
        set message = 'Xóa bài viết thành công';
    end if;
end $$
DELIMITER ;
-- f11: Quản lý xóa tài khoản (Quản trị viên xóa tài khoản người dùng và tất cả dữ liệu phụ thuộc một cách an toàn.)
DELIMITER $$
create procedure delete_user (in user_id_in  int, out message text) 
begin 
	-- kiểm tra lỗi
	declare error_message text;
    declare exit handler for sqlexception
    begin
		get diagnostics condition 1
        error_message = message_text;
        rollback; 
        set message = error_message;
    end;
    start transaction;
    -- xóa like
    delete from likes 
    where user_id = user_id_in;
    -- xóa comment 
    delete from comments
    where user_id = user_id_in;
    -- xóa bài viết 
    delete from posts
    where user_id = user_id_in;
    -- xóa quan bạn bè
    delete from friends
    where user_id = user_id_in or  friend_id = user_id_in;
    -- xóa user
    delete from users
    where user_id = user_id_in;
    commit;
    set message = 'Xóa thành công';
end $$ 
DELIMITER ;
