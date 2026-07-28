class Student {
  String fname;
  String lname;
  int id;
  int year;
  String score;

  Student({
    required this.fname,
    required this.lname,
    required this.id,
    required this.year,
    required this.score,
  });

  String getDetails() {
    return 'Name: $fname $lname, ID: $id, Year: $year, Score: $score';
  }
}

  
 
  
 