import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/models/user.dart';

void main() {
  test('حرفا صورة الحساب: الاسم الأول واسم العائلة دون «ال»', () {
    expect(AppUser.initialsOf('محمد الحسناوي'), 'م ح');
    expect(AppUser.initialsOf('يوسف ناصر'), 'ي ن');
    expect(AppUser.initialsOf('كريم عبد الله'), 'ك ع');
    expect(AppUser.initialsOf('عبد الرحمن الشافعي'), 'ع ش');
    expect(AppUser.initialsOf('  سامي  '), 'س');
    expect(AppUser.initialsOf(''), '؟');
    expect(AppUser.initialsOf('karim@gmail.com'), 'k');
  });
}
