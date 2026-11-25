import localUnitTest from './LocalUnit.test';
import timetableModelTest from './TimetableModel.test';

export default function testsuite() {
  localUnitTest();
  timetableModelTest();
}
