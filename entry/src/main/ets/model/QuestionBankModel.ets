// ==================== 我的题库（教师维护，本地持久化） ====================
export type QuestionType = 'single' | 'blank' | 'short'

export class BankQuestion {
  id: string = ''
  type: QuestionType = 'single'
  subject: string = ''
  stem: string = ''
  answer: string = ''
  createdAt: number = 0

  constructor(type: QuestionType, subject: string, stem: string, answer: string) {
    this.id = `q_${Date.now()}_${Math.floor(Math.random() * 1000)}`
    this.type = type
    this.subject = subject
    this.stem = stem
    this.answer = answer
    this.createdAt = Date.now()
  }
}

export function questionTypeLabel(t: QuestionType): string {
  if (t === 'blank') {
    return '填空题'
  }
  if (t === 'short') {
    return '简答题'
  }
  return '单选题'
}

export class QuestionBankStore {
  static list(): BankQuestion[] {
    return AppStorage.get<BankQuestion[]>('questionBank') ?? []
  }

  static save(list: BankQuestion[]): void {
    AppStorage.setOrCreate<BankQuestion[]>('questionBank', list)
  }

  static add(q: BankQuestion): void {
    QuestionBankStore.save([q].concat(QuestionBankStore.list()))
  }

  static remove(id: string): boolean {
    let list = QuestionBankStore.list()
    let next = list.filter((q: BankQuestion) => q.id !== id)
    if (next.length === list.length) {
      return false
    }
    QuestionBankStore.save(next)
    return true
  }

  static ensureSeed(): void {
    if (AppStorage.get<boolean>('questionBankSeeded') === true) {
      return
    }
    AppStorage.setOrCreate<boolean>('questionBankSeeded', true)
    if (QuestionBankStore.list().length > 0) {
      return
    }
    QuestionBankStore.save([
      new BankQuestion('single', '计算机基础', '下列哪种数据结构适合实现「先进先出」？A. 栈 B. 队列 C. 二叉树 D. 哈希表', 'B'),
      new BankQuestion('short', '计算机基础', '简述进程与线程的区别。', '进程是资源分配的基本单位，线程是 CPU 调度的基本单位；同进程内线程共享内存空间。')
    ])
  }
}
