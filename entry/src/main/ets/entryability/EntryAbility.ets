import { AbilityConstant, UIAbility, Want, ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { TodoItem, ScheduleItem, NoteItem, NotebookItem, FavItem, PostItem, MessageItem, ChatMessage, CommentItem, defaultPosts, defaultMessages, defaultComments, defaultTodos, defaultSchedules, defaultNotes, defaultNotebooks, normalizeNotes, normalizeNotebooks, mergedFavs, FeedbackItem, FollowItem, PointRecord, CoinRecord, CoinOrder, PracticeQuestion, SurveyQuestion, Teacher, defaultTeachers, normalizeTeachers } from '../model/DataModel';
import { TaskItem, PointRule } from '../model/InteractionModel';
import { CheckinItem, defaultCheckins } from '../model/CourseModel';
import { CourseItem } from '../model/TimetableModel';
import { ThemeColor } from '../utils/ThemeColor';
import { dailyLogin } from '../model/GrowthModel';
import { Homework, HomeworkSubmission, GroupMsg, GroupMember } from '../model/HomeworkModel';
import { ChatGroup, GroupNotice, GroupFile, GroupReport, ensureGroupSeed } from '../model/GroupModel';
import { AssistantInfo, Permission } from '../model/PermissionModel';
import { BankQuestion } from '../model/QuestionBankModel';
import { ResourceItem } from '../model/ResourceModel';
import { MessageCenter } from '../model/MessageCenterModel';
import { TeacherReview } from '../model/ReviewModel';
import { AccountStore } from '../model/AccountStore';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 🌟 账号数据库（学号 / 教工号注册登录）初始化，表结构在 AccountStore 中创建
    AccountStore.init(this.context)
    // 🌟 本地持久化（等价于 H5 的 localStorage）：写入磁盘，重启应用数据不丢失
    // 注意：persistProp 会自动读取磁盘上的旧值，不能用 setOrCreate 覆盖
    PersistentStorage.persistProp<TodoItem[]>('todoList', []);
    PersistentStorage.persistProp<ScheduleItem[]>('scheduleList', []);
    PersistentStorage.persistProp<NoteItem[]>('noteList', []);
    PersistentStorage.persistProp<FavItem[]>('favList', []);
    PersistentStorage.persistProp<PostItem[]>('postList', []);
    PersistentStorage.persistProp<MessageItem[]>('messageList', []);
    // 🌟 消息按身份分账：messageStore = { student/teacher/assistant: MessageItem[] }
    PersistentStorage.persistProp<Record<string, MessageItem[]>>('messageStore', {});
    PersistentStorage.persistProp<string>('messageScope', '');
    PersistentStorage.persistProp<string>('messageSeededScope', '');
    PersistentStorage.persistProp<string>('nickname', '');
    // 🌟 发现页已读帖子 id：底部「发现」红点 = 尚未查看过的帖子数
    PersistentStorage.persistProp<string[]>('readPostIds', []);
    PersistentStorage.persistProp<boolean>('seeded', false);
    // 注册登录 / 头像 / 深浅色模式 / 聊天记录
    PersistentStorage.persistProp<boolean>('isLogged', false);
    PersistentStorage.persistProp<string>('regAccount', '');
    PersistentStorage.persistProp<string>('regPassword', '');
    PersistentStorage.persistProp<string>('avatarEmoji', '');
    // 🌟 自定义头像（相册图片在沙箱中的路径）
    PersistentStorage.persistProp<string>('avatarUri', '');
    PersistentStorage.persistProp<number>('colorModeSetting', 0); // 0 浅色 / 1 深色
    PersistentStorage.persistProp<Record<string, ChatMessage[]>>('chatMap', {});
    // 帖子评论：按帖子 id 分组持久化
    PersistentStorage.persistProp<Record<string, CommentItem[]>>('commentMap', {});
    // 关注的作者列表
    PersistentStorage.persistProp<string[]>('followList', []);
    // 🌟 好友列表（登录后可添加）
    PersistentStorage.persistProp<string[]>('friendList', []);
    // 聊天背景透明度（10~100，越小越透明）
    PersistentStorage.persistProp<number>('chatBgOpacity', 100);
    // 🌟 聊天主题：default / japanese / pastoral / luxury
    PersistentStorage.persistProp<string>('chatTheme', 'default');
    // 🌟 记住我：登录页自动填充账号密码，快速登录
    PersistentStorage.persistProp<boolean>('rememberMe', true);
    // 🌟 历史数据迁移：旧版本昵称是写死的「张同学 / 张老师」，统一改为登录名
    let savedName = AppStorage.get<string>('nickname') ?? '';
    let savedAcc = AppStorage.get<string>('regAccount') ?? '';
    if (savedAcc !== '' && (savedName === '' || savedName === '张同学' || savedName === '张老师')) {
      AppStorage.setOrCreate<string>('nickname', savedAcc);
    }
    // ==================== 课程模块持久化 ====================
    // 学习语言：ko 韩语 / en 英语 / zh 汉语（在「我的」页修改）
    PersistentStorage.persistProp<string>('languageSetting', 'en');
    // 课程进度：courseId -> 已完成课时数
    PersistentStorage.persistProp<Record<string, number>>('courseProgress', {});
    // 课程课时明细：courseId -> 已完成课时下标（如 "0,1,3"），用于按实际完成数计数
    PersistentStorage.persistProp<Record<string, string>>('lessonDoneIndexes', {});
    // 已掌握单词（语言+单词组合键，去重计数）
    PersistentStorage.persistProp<string[]>('wordKnown', []);
    // 练习批次游标：模块_语言 -> 当前批次（完成一批后轮换到下一批）
    PersistentStorage.persistProp<Record<string, number>>('batchCursor', {});
    // 学习日志：date -> 当日学习分钟数（进度追踪与连续打卡）
    PersistentStorage.persistProp<Record<string, number>>('studyLog', {});
    // 🌟 按学科/语言分账的学习日志：subject -> { date: minutes }，避免跨课程串学习进度
    PersistentStorage.persistProp<Record<string, Record<string, number>>>('studyLogBySubject', {});
    // 🌟 历史数据迁移：旧版本只有全局 studyLog，无法追溯归属，归入当前学习语言，避免升级后进度清零
    let scopedStudyLog = AppStorage.get<Record<string, Record<string, number>>>('studyLogBySubject');
    if (scopedStudyLog === undefined || Object.keys(scopedStudyLog).length === 0) {
      let legacyStudyLog = AppStorage.get<Record<string, number>>('studyLog');
      let legacyLang = AppStorage.get<string>('languageSetting') ?? 'en';
      if (legacyStudyLog !== undefined && Object.keys(legacyStudyLog).length > 0 && legacyLang !== '') {
        let migrated: Record<string, Record<string, number>> = {};
        migrated[legacyLang] = legacyStudyLog;
        AppStorage.setOrCreate('studyLogBySubject', migrated);
      }
    }
    // 学习社区打卡动态
    PersistentStorage.persistProp<CheckinItem[]>('checkinList', []);
    // 已解锁成就 id 列表
    PersistentStorage.persistProp<string[]>('achievementList', []);
    // 语法 / 听力一次全对的标记（用于解锁对应成就）
    PersistentStorage.persistProp<boolean>('quizPerfect', false);
    PersistentStorage.persistProp<boolean>('listenPerfect', false);
    // ==================== 成长体系持久化（经验 + 硬币 + 已购课程） ====================
    PersistentStorage.persistProp<number>('userExp', 0);
    PersistentStorage.persistProp<number>('coins', 0);
    // 🌟 互动点赞状态：再次进入金币页仍显示已点赞，避免每次重置成未点赞
    PersistentStorage.persistProp<boolean>('coinLiked', false);
    // 🌟 金币收支明细：与余额一起持久化，避免重进金币页时余额被演示数据重置
    PersistentStorage.persistProp<CoinRecord[]>('coinRecords', []);
    // 🌟 金币充值订单：支持在「我的金币」查看订单号 / 金额并申请开票
    PersistentStorage.persistProp<CoinOrder[]>('coinOrders', []);
    PersistentStorage.persistProp<string>('lastLoginDate', '');
    PersistentStorage.persistProp<string>('chatAwardDate', '');
    PersistentStorage.persistProp<number>('chatExpCount', 0);
    PersistentStorage.persistProp<number>('chatCoinCount', 0);
    PersistentStorage.persistProp<string[]>('purchasedCourses', []);
    // ==================== 身份 + 班级模块持久化 ====================
    // 学生 / 老师身份 + 注册时与账号绑定的身份
    PersistentStorage.persistProp<string>('userRole', 'student');
    PersistentStorage.persistProp<string>('regRole', '');
    // 班级作业与提交、班级群聊消息
    PersistentStorage.persistProp<Homework[]>('hwList', []);
    PersistentStorage.persistProp<HomeworkSubmission[]>('hwSubs', []);
    PersistentStorage.persistProp<GroupMsg[]>('classGroupMsgs', []);
    // 班级群设置：本群昵称 / 群公告 / 是否退群
    PersistentStorage.persistProp<string>('classGroupNick', '');
    PersistentStorage.persistProp<string>('classGroupNotice', '');
    PersistentStorage.persistProp<boolean>('classGroupQuit', false);
    PersistentStorage.persistProp<boolean>('classGroupSeeded', false);
    // ==================== 班级群（师生共用）持久化 ====================
    // 群组 / 成员 / 公告 / 文件归档 / 举报
    PersistentStorage.persistProp<ChatGroup[]>('chatGroups', []);
    PersistentStorage.persistProp<Record<string, GroupMember[]>>('groupMembersMap', {});
    PersistentStorage.persistProp<GroupNotice[]>('groupNotices', []);
    PersistentStorage.persistProp<GroupFile[]>('groupFiles', []);
    PersistentStorage.persistProp<GroupReport[]>('groupReports', []);
    // 子分组群消息 / 云端聊天归档 / 未读红点 / 免打扰模式
    PersistentStorage.persistProp<Record<string, GroupMsg[]>>('groupMsgsMap', {});
    PersistentStorage.persistProp<Record<string, GroupMsg[]>>('groupChatArchive', {});
    PersistentStorage.persistProp<Record<string, number>>('groupUnreadMap', {});
    PersistentStorage.persistProp<Record<string, string>>('groupMuteMap', {});
    // 助教建群权限 / 文件保留天数 / 学生是否已退出课程
    PersistentStorage.persistProp<boolean>('assistantCanCreate', false);
    PersistentStorage.persistProp<number>('fileRetentionDays', 30);
    PersistentStorage.persistProp<boolean>('courseQuit', false);
    PersistentStorage.persistProp<boolean>('groupSeeded', false);
    // 自由练习轮换：每个练习出现次数 + 批次游标
    PersistentStorage.persistProp<Record<string, number>>('practiceSeen', {});
    PersistentStorage.persistProp<Record<string, number>>('practiceCursor', {});
    // 老师「洞察学情」成就标记（查看过学生进度即解锁）
    PersistentStorage.persistProp<boolean>('t_viewedProgress', false);

    // 新增功能持久化
    PersistentStorage.persistProp<FollowItem[]>('followItems', []);
    PersistentStorage.persistProp<boolean>('followSeeded', false);
    // 🌟 教学互动任务台账（签到 / 练习 / 问卷 / 抽选）+ 学分规则
    PersistentStorage.persistProp<TaskItem[]>('interactionTasks', []);
    PersistentStorage.persistProp<Record<string, PointRule>>('pointRules', {});
    PersistentStorage.persistProp<PracticeQuestion[]>('practiceQuestions', []);
    PersistentStorage.persistProp<PointRecord[]>('pointRecords', []);
    PersistentStorage.persistProp<boolean>('pointEnabled', true);
    PersistentStorage.persistProp<number>('pointsTotal', 0);
    PersistentStorage.persistProp<SurveyQuestion[]>('surveyQuestions', []);
    PersistentStorage.persistProp<boolean>('isDark', false);
    PersistentStorage.persistProp<string>('skinMode', 'light');
    // 🌟 账号设置：绑定手机号 + 客服反馈记录（本地模拟，无后端）
    PersistentStorage.persistProp<string>('boundPhone', '');
    PersistentStorage.persistProp<FeedbackItem[]>('feedbackList', []);
    // ==================== 课程表持久化 ====================
    // 课程数据（本地缓存）+ 表格主题 + 模拟云端快照（按账号分组）
    PersistentStorage.persistProp<CourseItem[]>('courseTable', []);
    PersistentStorage.persistProp<boolean>('courseTableAutoSeeded', false);
    PersistentStorage.persistProp<string>('courseTableTheme', 'classic');
    PersistentStorage.persistProp<Record<string, CourseItem[]>>('timetableCloud', {});
    PersistentStorage.persistProp<Record<string, string>>('timetableCloudTime', {});
    // ==================== 笔记模块持久化 ====================
    // 笔记本分类 / 本地模拟云端快照 / 离线模式开关
    PersistentStorage.persistProp<NotebookItem[]>('notebookList', []);
    PersistentStorage.persistProp<Record<string, NoteItem[]>>('noteCloud', {});
    PersistentStorage.persistProp<Record<string, string>>('noteCloudTime', {});
    PersistentStorage.persistProp<boolean>('noteOffline', false);

    // ==================== 讲师主页持久化 ====================
    // 授课名师列表（课程页轮播 + 讲师主页共用）+ 当前登录讲师本人的主页 id
    PersistentStorage.persistProp<Teacher[]>('teacherList', defaultTeachers());
    PersistentStorage.persistProp<string>('myTeacherId', '');

    // ==================== 全局通用模块持久化 ====================
    // 个人资料：学号 / 工号、个人简介、第三方绑定
    PersistentStorage.persistProp<string>('studentId', '');
    PersistentStorage.persistProp<string>('userBio', '');
    PersistentStorage.persistProp<string[]>('thirdPartyBinds', []);
    // 课程成员：学生已加入课程（key 为学科 id）
    PersistentStorage.persistProp<string[]>('enrolledCourses', []);
    PersistentStorage.persistProp<boolean>('enrollmentSeeded', false);
    // 助教名单（主讲教师添加）/ 教师题库 / 上传资源
    PersistentStorage.persistProp<AssistantInfo[]>('assistantList', []);
    PersistentStorage.persistProp<BankQuestion[]>('questionBank', []);
    PersistentStorage.persistProp<boolean>('questionBankSeeded', false);
    PersistentStorage.persistProp<ResourceItem[]>('resourceList', []);
    PersistentStorage.persistProp<boolean>('resourceSeeded', false);
    // 消息中心独立种子标记 / 弱网模拟 / 推送分项 / 隐私设置
    PersistentStorage.persistProp<boolean>('messageCenterSeeded', false);
    PersistentStorage.persistProp<boolean>('networkOnline', true);
    PersistentStorage.persistProp<boolean>('pushEnabled', true);
    PersistentStorage.persistProp<boolean>('pushClass', true);
    PersistentStorage.persistProp<boolean>('pushSignin', true);
    PersistentStorage.persistProp<boolean>('pushHomework', true);
    PersistentStorage.persistProp<boolean>('pushRecharge', true);
    PersistentStorage.persistProp<boolean>('pushReport', true);
    PersistentStorage.persistProp<boolean>('privacyShowProfile', true);
    PersistentStorage.persistProp<boolean>('privacyShowNotes', true);
    PersistentStorage.persistProp<boolean>('privacyShowFollow', false);
    PersistentStorage.persistProp<boolean>('privacyAnonymous', false);
    PersistentStorage.persistProp<boolean>('privacyCourseData', true);
    // 讲师匿名评价 / 金币免费任务领取记录（任务 id -> 最近领取日期）
    PersistentStorage.persistProp<TeacherReview[]>('teacherReviews', []);
    PersistentStorage.persistProp<Record<string, string>>('coinFreeClaims', {});
    // 任务定时提醒的系统提醒 id（taskId -> reminderId），用于提前发布 / 撤回时取消
    PersistentStorage.persistProp<Record<string, number>>('taskReminderIds', {});

    // 同步主题状态到 ThemeColor 工具类
    ThemeColor.isDark = AppStorage.get<boolean>('isDark') ?? false;

    // 🌟 讲师数据：空列表灌入演示数据；老数据补齐新增字段；校正「本人主页」指向
    let teacherList = AppStorage.get<Teacher[]>('teacherList');
    if (teacherList === undefined || teacherList.length === 0) {
      teacherList = defaultTeachers();
    } else {
      teacherList = normalizeTeachers(teacherList);
    }
    // 🌟 老数据校正：授课名师「李明华」已更名为「李季」
    teacherList = teacherList.map((t: Teacher) => {
      if (t.id === 't_li' && t.name === '李明华') {
        t.name = '李季'
      }
      return t
    })
    AppStorage.setOrCreate('teacherList', teacherList);
    let myTeacherId = AppStorage.get<string>('myTeacherId') ?? '';
    let hasMine = teacherList.some((t: Teacher) => t.id === myTeacherId);
    if (!hasMine && teacherList.length > 0) {
      AppStorage.setOrCreate('myTeacherId', teacherList[0].id);
    }

    // 首次启动：灌入帖子 / 消息演示数据；「清空本地数据」后不会重新生成
    if (!AppStorage.get<boolean>('seeded')) {
      AppStorage.setOrCreate('postList', defaultPosts());
      AppStorage.setOrCreate('messageList', defaultMessages());
      AppStorage.setOrCreate('seeded', true);
    }

    // 🌟 课程成员与消息中心：首次启动灌入默认课程与各类通知
    Permission.ensureEnrollmentSeed();
    // 🌟 先切换到当前身份的消息作用域，再灌种子：
    //    否则教师登录恢复时会先把教师种子写进上一个身份（学生）的账本
    MessageCenter.activateScope();
    MessageCenter.ensureSeed();

    // 🌟 评论为空时灌入种子评论（老用户升级后也能看到评论内容）
    let commentMap = AppStorage.get<Record<string, CommentItem[]>>('commentMap');
    if (commentMap === undefined || Object.keys(commentMap).length === 0) {
      AppStorage.setOrCreate('commentMap', defaultComments());
    }

    // 🌟 待办 / 日程 / 笔记 / 收藏为空时灌入初始演示数据（老用户升级后也能看到）
    let todos = AppStorage.get<TodoItem[]>('todoList');
    if (todos === undefined || todos.length === 0) {
      AppStorage.setOrCreate('todoList', defaultTodos());
    }
    let schedules = AppStorage.get<ScheduleItem[]>('scheduleList');
    if (schedules === undefined || schedules.length === 0) {
      AppStorage.setOrCreate('scheduleList', defaultSchedules());
    }
    // 🌟 笔记：空列表灌入演示数据；老数据补齐新增字段（笔记本 / 标签 / 图片 / 权限 / 版本号等）
    let notes = AppStorage.get<NoteItem[]>('noteList');
    if (notes === undefined || notes.length === 0) {
      AppStorage.setOrCreate('noteList', defaultNotes());
    } else {
      AppStorage.setOrCreate('noteList', normalizeNotes(notes));
    }
    // 🌟 笔记本：首次使用灌入默认分类，之后保证「默认笔记本」始终存在
    let notebooks = AppStorage.get<NotebookItem[]>('notebookList');
    if (notebooks === undefined || notebooks.length === 0) {
      AppStorage.setOrCreate('notebookList', defaultNotebooks());
    } else {
      AppStorage.setOrCreate('notebookList', normalizeNotebooks(notebooks));
    }
    // 🌟 收藏夹「缺哪条补哪条」：按 url 逐条补齐缺失的默认收藏（有变化才写回，避免每次启动都覆盖持久化）
    let favs = AppStorage.get<FavItem[]>('favList') ?? [];
    let merged = mergedFavs(favs);
    if (merged.length !== favs.length) {
      AppStorage.setOrCreate('favList', merged);
    }

    // 🌟 学习社区打卡：仅首次启动（key 未定义时）灌入演示打卡，「清空本地数据」后不再生成
    let checkins = AppStorage.get<CheckinItem[]>('checkinList');
    if (checkins === undefined) {
      AppStorage.setOrCreate('checkinList', defaultCheckins());
    }

    // 🌟 老数据迁移：消息页只保留和用户有关的信息——点赞/评论通知必须指向用户自己发的帖子
    let posts = AppStorage.get<PostItem[]>('postList') ?? [];
    let nickname = AppStorage.get<string>('nickname') ?? '张同学';
    if (posts.length > 0) {
      let authorOf: Record<string, string> = {};
      posts.forEach((p: PostItem) => {
        authorOf[p.id] = p.author;
      });
      let msgs = AppStorage.get<MessageItem[]>('messageList') ?? [];
      let filtered = msgs.filter((m: MessageItem) => {
        if (m.type === 'system' || m.postId === '') {
          return true; // 系统通知、好友群聊消息保留
        }
        let owner = authorOf[m.postId];
        return owner === nickname || owner === '张同学';
      });
      if (filtered.length !== msgs.length) {
        AppStorage.setOrCreate('messageList', filtered);
      }
    }

    // 🌟 启动时应用用户选择的深浅色模式（配合 resources/dark 颜色令牌自动换肤）
    if (AppStorage.get<number>('colorModeSetting') === 1) {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    } else {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    }

    // 🌟 班级群演示数据：首次启动灌入主群 / 子分组群 / 公告 / 文件归档 / 云端归档
    ensureGroupSeed();

    // 🌟 每日登录奖励：每天首次启动 +10 经验 +5 硬币（成长体系）
    dailyLogin();
  }

  // 🌟 切屏检测：应用退到后台时写入时间戳，随堂练习页据此发出切屏提醒
  onBackground(): void {
    AppStorage.setOrCreate('appBgStamp', Date.now());
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 🌟 未登录时必须先完成登录/注册（登录页不提供跳过入口），已登录直接进主页
    let startPage = AppStorage.get<boolean>('isLogged') ? 'pages/Index' : 'pages/common/LoginPage';
    windowStage.loadContent(startPage, (err) => {
      if (err.code) {
        return;
      }
    });
  }
}
