ALTER TABLE DEPARTMENTS
  ADD COLUMN DepartmentHeadUserID INT NULL AFTER DepartmentHead,
  ADD INDEX idx_departments_department_head_userid (DepartmentHeadUserID),
  ADD CONSTRAINT fk_departments_department_head_userid
    FOREIGN KEY (DepartmentHeadUserID)
    REFERENCES USERACCOUNTS(UserID)
    ON DELETE SET NULL;
