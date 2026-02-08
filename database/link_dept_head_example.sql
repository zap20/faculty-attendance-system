-- 1. Create a DepartmentHead user (if not exists)
INSERT INTO USERACCOUNTS (Username, Password, Role, IsActive, CreatedAt)
VALUES ('dept.head.cs', '$2y$10$abcdefghijklmnopqrstuv', 'DepartmentHead', 1, NOW());

-- 2. Link the new user to Computer Science department (assuming UserID = 10)
-- Replace 10 with the actual UserID from the INSERT above
UPDATE DEPARTMENTS
SET DepartmentHeadUserID = 10
WHERE DepartmentID = 1;

-- 3. Verify
SELECT 
    d.DepartmentID,
    d.DepartmentName,
    d.DepartmentHeadUserID,
    u.Username,
    u.Role
FROM DEPARTMENTS d
LEFT JOIN USERACCOUNTS u ON d.DepartmentHeadUserID = u.UserID
WHERE d.DepartmentID = 1;
