import { describe, it, expect } from '@ohos/hypium';
import {
  CourseItem,
  defaultStudentCourses,
  coursesOnDay,
  shouldGenerateStudentCourses,
  timeToMinutes
} from '../main/ets/model/TimetableModel';

// 学生端自动生成课表的单元测试
export default function timetableModelTest() {
  describe('timetableModelTest', () => {
    it('defaultStudentCourses_生成完整课表', 0, () => {
      let list: CourseItem[] = defaultStudentCourses();
      expect(list.length).assertEqual(11);
      list.forEach((c: CourseItem) => {
        expect(c.id.length > 0).assertTrue();
        expect(c.name.length > 0).assertTrue();
        expect(c.location.length > 0).assertTrue();
        expect(c.teacher.length > 0).assertTrue();
      });
    });

    it('defaultStudentCourses_星期与时间合法', 0, () => {
      let list: CourseItem[] = defaultStudentCourses();
      list.forEach((c: CourseItem) => {
        // 只排周一到周五
        expect(c.dayOfWeek >= 1 && c.dayOfWeek <= 5).assertTrue();
        // HH:mm 格式
        expect(c.startTime.indexOf(':')).assertEqual(2);
        expect(c.endTime.indexOf(':')).assertEqual(2);
        expect(c.startTime.length).assertEqual(5);
        expect(c.endTime.length).assertEqual(5);
        // 下课时间必须晚于上课时间
        expect(timeToMinutes(c.startTime) < timeToMinutes(c.endTime)).assertTrue();
      });
    });

    it('defaultStudentCourses_按星期和开始时间排序', 0, () => {
      let list: CourseItem[] = defaultStudentCourses();
      for (let i = 1; i < list.length; i++) {
        let prev = list[i - 1];
        let cur = list[i];
        expect(prev.dayOfWeek <= cur.dayOfWeek).assertTrue();
        if (prev.dayOfWeek === cur.dayOfWeek) {
          expect(timeToMinutes(prev.startTime) <= timeToMinutes(cur.startTime)).assertTrue();
        }
      }
    });

    it('defaultStudentCourses_覆盖周一到周五', 0, () => {
      let list: CourseItem[] = defaultStudentCourses();
      for (let day = 1; day <= 5; day++) {
        expect(coursesOnDay(list, day).length > 0).assertTrue();
      }
    });

    it('defaultStudentCourses_颜色索引合法且ID唯一', 0, () => {
      let list: CourseItem[] = defaultStudentCourses();
      let ids: string[] = [];
      list.forEach((c: CourseItem) => {
        expect(c.colorIndex >= 0 && c.colorIndex <= 7).assertTrue();
        // 同一门课在不同星期可重复，但 id 必须唯一
        expect(ids.indexOf(c.id)).assertEqual(-1);
        ids.push(c.id);
      });
    });

    it('shouldGenerateStudentCourses_空课表且未生成过时生成', 0, () => {
      expect(shouldGenerateStudentCourses(false, 0)).assertTrue();
    });

    it('shouldGenerateStudentCourses_已生成过不再生成', 0, () => {
      expect(shouldGenerateStudentCourses(true, 0)).assertFalse();
      expect(shouldGenerateStudentCourses(true, 6)).assertFalse();
    });

    it('shouldGenerateStudentCourses_已有课表时不覆盖', 0, () => {
      expect(shouldGenerateStudentCourses(false, 3)).assertFalse();
    });
  });
}
