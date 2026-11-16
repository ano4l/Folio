/// Self-authored sample material for an actual upload and AI generation flow.
abstract final class SampleCourse {
  static const title = 'Relational databases · sample lecture';
  static const text = '''RELATIONAL DATABASES
Folio sample lecture. This short lesson is demonstration material, not an official course handout.

1. Tables, rows and keys
A relational database represents information in tables. Each row describes one record and each column describes an attribute. A primary key uniquely identifies each row and cannot be null. A foreign key connects a row to a referenced key in another table. Referential integrity prevents a foreign key from referring to a key that does not exist, subject to the database's defined rules.

For example, a Student table can use student_id as its primary key. An Enrollment table can store student_id as a foreign key referring to Student. Deleting a student requires a deliberate rule for the enrollment records: restrict deletion, cascade deletion, or another defined action.

2. Normalisation
Normalisation organises data to reduce unnecessary repetition and update anomalies. First normal form requires individual values in each field rather than repeating groups. Second normal form requires first normal form and removes partial dependencies of non-key attributes on part of a composite candidate key. Third normal form removes transitive dependencies of non-key attributes on keys through other non-key attributes.

Consider a table with enrollment_id, student_id, student_name, course_id and course_name. Storing each student's name repeatedly means a name change could update some enrollments but leave others inconsistent. Separate Student and Course tables store the names once. Enrollment then records the relationship between them.

3. Joins
An inner join returns rows with matching values in both joined tables. A left join returns every row from the left table and matching rows from the right table; missing matches produce null values for the right table's columns. To list all students including those with no enrollment, use Student as the left table in a left join to Enrollment. An inner join would omit students without a match.

4. Transactions
A transaction groups database operations so they succeed or fail as a unit. Atomicity means all operations commit together or none do. Consistency means a transaction preserves defined constraints. Isolation controls how concurrent transactions interact. Durability means committed changes persist after successful completion, subject to the database's recovery guarantees.

If transferring credit between two accounts, debit and credit must be one transaction. A failure after the debit must roll back the transaction so it cannot leave only one side committed.

5. Indexes and access
An index can make relevant lookups faster, but it takes storage and adds work when indexed values change. Indexes should match actual query patterns rather than being added to every column. Parameterised queries separate values from SQL syntax and reduce SQL injection risk. Authorisation still needs to check which records each user can access.

REVISION PROMPTS
Explain why separate Student and Enrollment tables reduce name-update anomalies.
Compare an inner join and a left join for students without enrollments.
Describe what atomicity protects during a credit transfer.
Identify the difference between a primary key and a foreign key.
''';
}
